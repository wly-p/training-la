#!/usr/bin/env python3
"""元件庫契約檢查（正典 design-system/README.md §8）。

由 make lint 呼叫。--update-baseline 用來重設第 7 條的基線。

第 7 條是 ratchet（棘輪）而不是硬門檻：Presentation 層現在還有一百多處硬編樣式，
一次擋掉會讓所有工作停擺。所以記錄目前數量，只擋「變多」——每個榨取階段把數字往下推，
到階段 5 結束時應該歸零，屆時再把它改成硬門檻。
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DS   = ROOT / "design-system"
PKG  = ROOT / "Packages"
BASE = DS / ".presentation-baseline.json"

SECTIONS = ["1 身分", "2 介面", "3 變體", "4 狀態", "5 度量", "6 配色",
            "7 文字行為", "8 動態", "9 無障礙", "10 用法與禁用法", "11 組成", "12 變更紀錄"]
LITERAL_STYLE = re.compile(
    r"\.font\(\.system|\.font\(\.custom|cornerRadius|RoundedRectangle"
    r"|\.padding\((?:\.[a-z]+, )?[0-9]|\.frame\(.*?(?:width|height): ?[0-9]")
FEATURE_MODULES = ("Spec", "Plan", "Training", "History", "Settings", "Ability", "Reminders")

errs, warns = [], []
def err(c, m): errs.append(f"✘ [檢查 {c}] {m}")

def components():
    for layer in ("atoms", "molecules", "organisms"):
        d = DS / layer
        if d.is_dir():
            for c in sorted(p for p in d.iterdir() if p.is_dir()):
                yield layer, c

def section(md, title):
    m = re.search(rf"^## {re.escape(title)}.*?$(.*?)(?=^## |\Z)", md, re.M | re.S)
    return m.group(1) if m else None

# ── 2/3/4/5/6/11：逐元件 ────────────────────────────────────────────
n_comp = 0
for layer, cdir in components():
    name = cdir.name
    spec_p, prev_p = cdir / f"{name}.spec.md", cdir / f"{name}.preview.html"
    if not spec_p.exists(): err(1, f"{layer}/{name}：缺 {name}.spec.md"); continue
    if not prev_p.exists(): err(1, f"{layer}/{name}：缺 {name}.preview.html"); continue
    n_comp += 1
    spec, prev = spec_p.read_text(), prev_p.read_text()

    for s in SECTIONS:
        if not re.search(rf"^## {re.escape(s)}", spec, re.M):
            err(1, f"{name}.spec.md：缺第「{s}」節")

    # §1 的實作路徑要存在，且該檔只有一個 public 型別
    m = re.search(r"\|\s*實作\s*\|\s*`([^`]+)`\s*\|", spec)
    if not m:
        err(1, f"{name}.spec.md：第 1 節沒有標出實作檔路徑")
    else:
        swift = ROOT / m.group(1)
        if not swift.exists():
            err(1, f"{name}.spec.md：實作檔不存在 → {m.group(1)}")
        else:
            src = swift.read_text()
            pub = re.findall(r"^public (?:struct|enum|final class|class|protocol) (\w+)", src, re.M)
            if len(pub) != 1:
                err(2, f"{m.group(1)}：一個檔應該只有一個 public 元件，找到 {len(pub)} 個 {pub}")
            # §2 props ↔ init 參數
            props = section(spec, "2 介面") or ""
            declared = [x for x in re.findall(r"^\|\s*`?(\w+)`?\s*\|", props, re.M)
                        if x not in ("名稱",)]
            init = re.search(r"public init\(([^)]*)\)", src)
            actual = re.findall(r"(\w+)\s*:", init.group(1)) if init else []
            if not declared and actual:
                err(3, f"{name}：規格說無 props，但 init 有參數 {actual}")
            for d in declared:
                if d not in actual:
                    err(3, f"{name}：規格宣告的 prop `{d}` 不在 init 參數裡 {actual}")

    # §4 states ↔ preview 的 data-state
    ms = re.search(r"<!--\s*states:\s*([^>]+?)\s*-->", spec)
    if not ms:
        err(4, f"{name}.spec.md：第 4 節缺機器可讀的 `<!-- states: … -->` 宣告")
    else:
        want = [s.strip() for s in ms.group(1).split(",") if s.strip()]
        have = set(re.findall(r'data-state="([^"]+)"', prev))
        for s in want:
            if s not in have:
                err(4, f"{name}：規格宣告狀態 `{s}`，preview 沒有對應的 data-state")

    # §6 零字面色值（spec 與 preview）
    for label, txt in ((f"{name}.spec.md", spec), (f"{name}.preview.html", prev)):
        for lit in re.findall(r"#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)", txt):
            err(6, f"{label}：出現字面色值 `{lit}`，只准用語意 token / var(--…)")

    # preview 自足
    for u in re.findall(r'(?:src|href)="(https?:)?//[^"]+"', prev):
        err(6, f"{name}.preview.html：有外部請求，preview 必須自足")

    # preview 用到的 CSS 變數必須在 tokens.css 裡定義（打錯名字會靜默渲染成空值）
    defined = set(re.findall(r"^\s*(--[a-z0-9-]+):", (DS / "tokens/tokens.css").read_text(), re.M))
    for v in sorted(set(re.findall(r"var\((--[a-z0-9-]+)\)", prev))):
        if v not in defined:
            err(9, f"{name}.preview.html：用了未定義的 token `var({v})`")

    # §11 組成宣告的元件要真的存在
    if layer != "atoms":
        comp = section(spec, "11 組成") or ""
        for ref in re.findall(r"`(TL\w+)`", comp):
            if not any(c.name == ref for _, c in components()):
                err(11, f"{name}：第 11 節宣告的組成元件 `{ref}` 不在元件庫裡")

# ── 7：Presentation 層字面樣式（ratchet）──────────────────────────
counts = {}
for pkg in sorted(p.name for p in PKG.iterdir() if p.is_dir() and p.name != "DesignSystem"):
    n = 0
    for f in (PKG / pkg).rglob("*.swift"):
        if ".build" in f.parts or "Presentation" not in str(f):
            continue
        n += len(LITERAL_STYLE.findall(f.read_text()))
    if n:
        counts[pkg] = n

if "--update-baseline" in sys.argv:
    BASE.write_text(json.dumps(counts, indent=2, sort_keys=True) + "\n")
    print(f"✔ 基線已更新：{counts}（總計 {sum(counts.values())}）")
    sys.exit(0)

base = json.loads(BASE.read_text()) if BASE.exists() else {}
for pkg, n in counts.items():
    b = base.get(pkg)
    if b is None:
        err(7, f"{pkg}：Presentation 有 {n} 處字面樣式但基線沒有這個 package，跑 --update-baseline")
    elif n > b:
        err(7, f"{pkg}：Presentation 字面樣式從 {b} 增加到 {n}——應用層不得定義樣式（正典 §4 規則一）")
    elif n < b:
        warns.append(f"↓ {pkg}：{b} → {n}，記得跑 scripts/check-design-system.py --update-baseline")

# ── 8：DesignSystem 不得認識 domain ────────────────────────────────
for f in (PKG / "DesignSystem").rglob("*.swift"):
    if ".build" in f.parts:
        continue
    for imp in re.findall(r"^import (\w+)", f.read_text(), re.M):
        if imp.startswith(FEATURE_MODULES):
            err(8, f"{f.relative_to(ROOT)}：DesignSystem 不准 import 功能 package（{imp}）")

for w in warns: print(w)
if errs:
    print("\n".join(errs)); sys.exit(1)
tot = sum(counts.values())
print(f"✔ 元件庫契約通過（{n_comp} 個元件；Presentation 字面樣式 {tot} 處，未超過基線）")
