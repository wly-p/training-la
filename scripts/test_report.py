#!/usr/bin/env python3
"""把測試結果解析後上傳 Notion 的 Test Result 資料庫。

由 `make test-unit` / `make test-uitest` 在 `REPORT=true` 時呼叫，也可以自己跑：

    python3 scripts/test_report.py --kind unit --language n/a --dir test-reports

結構對齊使用者在 Notion 建好的樣板：每次執行是「執行紀錄」DB 的一頁（帶統計數字），
點進去有一個子資料庫列出每個 case。

**這支腳本不該影響測試的成敗**：呼叫端已經用 `|| echo` 吞掉錯誤，這裡也不做任何會中斷
建置的事；上傳失敗就印訊息、回傳非 0，由呼叫端決定怎麼處理。
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import pathlib
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field

NOTION_VERSION = "2022-06-28"
RUN_DB = "3afffcef-611f-804d-887e-e6377c82170c"
CASE_DB_TITLE = "Test Case Detail"
# Notion 的速率限制約每秒三次；留一點餘裕免得整批被擋。
REQUEST_INTERVAL = 0.34


@dataclass
class Case:
    name: str
    suite: str
    result: str          # pass / failed / skipped
    duration: float | None = None
    reason: str = ""


@dataclass
class Run:
    kind: str
    language: str
    cases: list[Case] = field(default_factory=list)

    @property
    def passed(self) -> int:
        return sum(1 for c in self.cases if c.result == "pass")

    @property
    def failed(self) -> int:
        return sum(1 for c in self.cases if c.result == "failed")

    @property
    def skipped(self) -> int:
        return sum(1 for c in self.cases if c.result == "skipped")

    @property
    def duration(self) -> float:
        return round(sum(c.duration or 0 for c in self.cases), 2)


# --------------------------------------------------------------------------- 解析

def parse_junit(report_dir: pathlib.Path) -> list[Case]:
    """swift test --xunit-output 產生的 JUnit XML。

    swift-testing 與 XCTest 各吐一份（後者檔名多了 `-swift-testing` 後綴），兩份都收。
    """
    cases: list[Case] = []
    for path in sorted(glob.glob(str(report_dir / "unit-*.xml"))):
        package = re.sub(r"^unit-|(-swift-testing)?\.xml$", "", pathlib.Path(path).name)
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError as error:
            print(f"⚠️ 解析不了 {path}：{error}", file=sys.stderr)
            continue

        for node in root.iter("testcase"):
            failure = node.find("failure")
            skipped = node.find("skipped")
            if failure is not None:
                result, reason = "failed", (failure.get("message") or failure.text or "")
            elif skipped is not None:
                result, reason = "skipped", (skipped.text or "")
            else:
                result, reason = "pass", ""

            raw_time = node.get("time")
            cases.append(Case(
                name=node.get("name", "?"),
                # classname 是測試套件；套件名相同時靠 package 區分。
                suite=f"{package} · {node.get('classname', '?')}",
                result=result,
                duration=float(raw_time) if raw_time else None,
                reason=reason.strip(),
            ))
    return cases


def parse_xcresult(bundle: pathlib.Path) -> list[Case]:
    """UITests 的 .xcresult。

    `xcresulttool get test-results tests` 給每個 case 的名稱／結果／耗時；
    失敗原因在 `summary` 的 `testFailures`，用 test identifier 對回去。
    """
    def run(*args: str) -> dict:
        output = subprocess.run(
            ["xcrun", "xcresulttool", "get", "test-results", *args, "--path", str(bundle)],
            capture_output=True, text=True, check=True,
        ).stdout
        return json.loads(output)

    reasons: dict[str, str] = {}
    for failure in run("summary").get("testFailures", []):
        reasons[failure.get("testIdentifierString", "")] = failure.get("failureText", "")

    cases: list[Case] = []

    def walk(node: dict, suite: str) -> None:
        kind = node.get("nodeType")
        name = node.get("name", "?")
        if kind == "Test Case":
            status = {"Passed": "pass", "Failed": "failed", "Skipped": "skipped"}
            identifier = node.get("nodeIdentifier", "")
            cases.append(Case(
                name=name,
                suite=suite,
                result=status.get(node.get("result", ""), "failed"),
                duration=node.get("durationInSeconds"),
                reason=reasons.get(identifier, "").strip(),
            ))
            return
        child_suite = name if kind == "Test Suite" else suite
        for child in node.get("children", []):
            walk(child, child_suite)

    for node in run("tests").get("testNodes", []):
        walk(node, "")
    return cases


# --------------------------------------------------------------------------- Notion

class Notion:
    def __init__(self, token: str):
        self.token = token
        self._last_call = 0.0

    def _request(self, method: str, path: str, payload: dict | None = None) -> dict:
        # 手動節流：Notion 大約每秒三次，整批寫 case 時很容易撞到。
        wait = REQUEST_INTERVAL - (time.monotonic() - self._last_call)
        if wait > 0:
            time.sleep(wait)
        self._last_call = time.monotonic()

        request = urllib.request.Request(
            f"https://api.notion.com/v1/{path}",
            method=method,
            data=json.dumps(payload).encode() if payload is not None else None,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Notion-Version": NOTION_VERSION,
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            raise RuntimeError(f"Notion {method} {path} 失敗：{error.read().decode()[:300]}") from error

    def create_page(self, payload: dict) -> str:
        return self._request("POST", "pages", payload)["id"]

    def create_database(self, payload: dict) -> str:
        return self._request("POST", "databases", payload)["id"]


def text(value: str, limit: int = 2000) -> list[dict]:
    """Notion 單一 rich_text 上限 2000 字；失敗訊息很容易超過，截斷並標明。"""
    value = value or ""
    if len(value) > limit:
        value = value[: limit - 3] + "..."
    return [{"type": "text", "text": {"content": value}}] if value else []


def git(*args: str) -> str:
    try:
        return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def upload(notion: Notion, run: Run) -> str:
    branch = git("rev-parse", "--abbrev-ref", "HEAD")
    started = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    label = f"{run.kind} · {time.strftime('%Y-%m-%d %H:%M')}"
    if run.language != "n/a":
        label += f" · {run.language}"

    run_page = notion.create_page({
        "parent": {"database_id": RUN_DB},
        "properties": {
            "run name": {"title": text(label)},
            "type": {"select": {"name": run.kind}},
            # Phase 1 只有本機執行；接上 CI 之後這裡改成看環境變數。
            "trigger": {"select": {"name": "手動"}},
            "language": ({"select": {"name": run.language}} if run.language != "n/a" else {"select": None}),
            "選取": {"select": {"name": "failed" if run.failed else "pass"}},
            "total": {"number": len(run.cases)},
            "pass count": {"number": run.passed},
            "fail count": {"number": run.failed},
            "skip count": {"number": run.skipped},
            "duration (s)": {"number": run.duration},
            "branch": {"rich_text": text(branch)},
            "start at": {"date": {"start": started}},
        },
    })

    case_db = notion.create_database({
        "parent": {"page_id": run_page},
        "title": text(CASE_DB_TITLE),
        "properties": {
            "name": {"title": {}},
            "suite": {"rich_text": {}},
            "result": {"select": {"options": [
                {"name": "pass", "color": "green"},
                {"name": "failed", "color": "red"},
                {"name": "skipped", "color": "gray"},
            ]}},
            "duration (s)": {"number": {"format": "number"}},
            "fail reason": {"rich_text": {}},
        },
    })

    for index, case in enumerate(run.cases, start=1):
        notion.create_page({
            "parent": {"database_id": case_db},
            "properties": {
                "name": {"title": text(case.name)},
                "suite": {"rich_text": text(case.suite)},
                "result": {"select": {"name": case.result}},
                "duration (s)": {"number": round(case.duration, 3) if case.duration else None},
                "fail reason": {"rich_text": text(case.reason)},
            },
        })
        if index % 25 == 0:
            print(f"    ...已上傳 {index}/{len(run.cases)}")

    return run_page


# --------------------------------------------------------------------------- CLI

def read_token() -> str:
    if token := os.environ.get("NOTION_PAT"):
        return token
    # repo 之外的本機設定檔（公開 repo 不放任何金鑰）
    config = pathlib.Path(__file__).resolve().parents[2] / ".notion.config"
    if config.exists():
        match = re.search(r'NOTION_PAT="([^"]+)"', config.read_text())
        if match:
            return match.group(1)
    raise RuntimeError(f"找不到 NOTION_PAT（環境變數或 {config}）")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kind", choices=["unit", "ui"], required=True)
    parser.add_argument("--language", default="n/a")
    parser.add_argument("--dir", default="test-reports")
    args = parser.parse_args()

    report_dir = pathlib.Path(args.dir)
    if args.kind == "unit":
        cases = parse_junit(report_dir)
    else:
        bundle = report_dir / f"uitest-{args.language}.xcresult"
        if not bundle.exists():
            print(f"⚠️ 找不到 {bundle}", file=sys.stderr)
            return 1
        cases = parse_xcresult(bundle)

    if not cases:
        print("⚠️ 沒有解析到任何測試 case，不上傳", file=sys.stderr)
        return 1

    run = Run(kind=args.kind, language=args.language, cases=cases)
    print(f"==> 解析到 {len(cases)} 個 case（pass {run.passed} / failed {run.failed} / skipped {run.skipped}）")

    try:
        page = upload(Notion(read_token()), run)
    except RuntimeError as error:
        print(f"⚠️ {error}", file=sys.stderr)
        return 1

    print(f"==> 已上傳 Notion：https://www.notion.so/{page.replace('-', '')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
