#!/usr/bin/env python3
"""從各元件的 spec.md 抽出 components.json ＋ index.html。

**不是新的真相來源**——每個欄位都來自 spec 十二節裡已經有的資訊。
設計端要組畫面時讀這一份就知道有哪些元件、各自收什麼 props，
不必逐份開 40 個 spec（開了也容易猜錯 props，然後被迫硬編，
規則一就從設計端先破功）。
"""
import datetime, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DS   = ROOT / "design-system"
JSON = DS / "components.json"
HTML = DS / "index.html"
LEVELS = [("atoms", "L1 原子"), ("molecules", "L2 分子"), ("organisms", "L3 有機體")]

def sect(md, title):
    m = re.search(rf"^## {re.escape(title)}.*?$(.*?)(?=^## |\Z)", md, re.M | re.S)
    return m.group(1) if m else ""

def kv(md, key):
    m = re.search(rf"^\|\s*{re.escape(key)}\s*\|\s*(.+?)\s*\|\s*$", md, re.M)
    return m.group(1).strip().strip("`") if m else None

def rows(table_md):
    """吃 markdown 表格，回傳去掉表頭與分隔線的資料列。"""
    out = []
    for line in table_md.splitlines():
        line = line.strip()
        if not line.startswith("|") or set(line) <= set("|- :"):
            continue
        cells = [c.strip().strip("`") for c in line.strip("|").split("|")]
        if cells and cells[0] in ("名稱", "類別", "日期", "", "（無）", "用途"):
            continue
        out.append(cells)
    return out

def collect():
    comps = []
    for layer, label in LEVELS:
        d = DS / layer
        if not d.is_dir():
            continue
        for cdir in sorted(p for p in d.iterdir() if p.is_dir()):
            spec_p = cdir / f"{cdir.name}.spec.md"
            if not spec_p.exists():
                continue
            md = spec_p.read_text()
            comps.append(parse(md, cdir.name, layer, label))
    return comps

def parse(md, name, layer, label):
    s1, s2, s3, s4, s10, s11 = (sect(md, x) for x in (
        "1 身分", "2 介面", "3 變體 variants", "4 狀態 states ★",
        "10 用法與禁用法", "11 組成 ★"))
    st = re.search(r"<!--\s*states:\s*([^>]+?)\s*-->", s4)
    th = re.search(r"<!--\s*themes:\s*([^>]+?)\s*-->", s4)
    split = lambda m: [x.strip() for x in m.group(1).split(",") if x.strip()] if m else []
    ids = re.findall(r"`([0-9]+[a-z])`", kv(s1, "原型 id") or "")
    note = re.sub(r"[`（(][^）)]*[）)]?", "", kv(s1, "原型 id") or "").strip(" 。") or None
    return {
        "name": name,
        "level": label.split()[0],
        "layer": layer,
        "responsibility": kv(s1, "職責"),
        "prototypeIds": ids,
        "prototypeNote": note,
        "props": props_of(s2),
        "slots": inline_list(s2, "Slots"),
        "events": inline_list(s2, "事件"),
        "variants": variants_of(s3),
        "states": split(st),
        "themes": split(th),
        "dontUseFor": dont_use_for(s10),
        "composedOf": sorted(set(re.findall(r"`(TL\w+)`", s11))) or None,
        "paths": {
            "spec": f"{layer}/{name}/{name}.spec.md",
            "preview": f"{layer}/{name}/{name}.preview.html",
            "impl": kv(s1, "實作"),
        },
    }

NONE = ("（無）", "無", "N/A", "無。", "N/A。")

def props_of(s2):
    out = []
    for r in rows(s2):
        if len(r) < 4 or r[0] in NONE or not r[0]:
            continue
        out.append({"name": r[0], "type": r[1], "required": r[2],
                    "default": r[3], "description": r[4] if len(r) > 4 else None})
    return out

def inline_list(s2, label):
    """`**Slots** — …` / `**事件** — …` 這種一行式宣告。回傳 [] 表示明確沒有。"""
    m = re.search(rf"\*\*{label}\*\*\s*[—-]+\s*(.+)", s2)
    if not m:
        return []
    body = m.group(1).strip()
    if body.startswith(NONE):
        return []
    return [x.strip() for x in re.findall(r"`(\w+)`", body)] or [body]

def variants_of(s3):
    body = s3.strip()
    if not body or body.startswith(NONE):
        return []
    return [r[0] for r in rows(s3) if r and r[0] not in NONE] or [body.splitlines()[0]]

def dont_use_for(s10):
    """第 10 節『不要用它』底下的條列。這是防止設計端用錯的那幾句話。"""
    m = re.search(r"\*\*不要用它\*\*[^\n]*\n(.*?)(?=\n\*\*|\Z)", s10, re.S)
    if not m:
        return []
    return [re.sub(r"^[-*]\s*", "", ln).strip()
            for ln in m.group(1).splitlines() if ln.strip().startswith(("-", "*"))]
    return comps

def render(comps):
    tok = json.loads((DS / "tokens/tokens.json").read_text())
    L = ['<!doctype html>', '<meta charset="utf-8">', '<title>Training La 元件庫</title>',
         '<link rel="stylesheet" href="tokens/tokens.css">',
         '<link rel="stylesheet" href="preview.css">',
         '<style>',
         '  a { color: var(--accent-on-surface); text-decoration: none; }',
         '  a:hover { text-decoration: underline; }',
         '  .lvl { color: var(--text-tertiary); font-size: var(--font-row-sub); }',
         '</style>',
         '<h1>Training La 元件庫</h1>',
         f'<p class="note">token 版本 {tok["meta"]["version"]}　·　'
         f'{len(comps)} 個元件　·　規則見 <a href="README.md">README.md</a>、'
         f'規格樣板見 <a href="_template.spec.md">_template.spec.md</a>　·　'
         f'token 與契約的改動見 <a href="CHANGELOG.md">CHANGELOG.md</a><br>'
         f'<b>這輪先讀 <a href="HANDOFF.md">HANDOFF.md</a></b>（跟上輪的差別、想請你看什麼）。<br>'
         f'組畫面時讀 <a href="components.json">components.json</a>（機器讀的登錄檔，'
         f'每個元件的 props／狀態／組成都在裡面），再開個別 preview。<br>'
         f'token 的實際樣子見 <a href="tokens/tokens.preview.html">tokens.preview.html</a>。</p>']
    for layer, label in LEVELS:
        group = [c for c in comps if c["layer"] == layer]
        L.append(f'<div class="kicker">{label}（{len(group)}）</div>')
        if not group:
            L.append('<p class="note">（尚無元件）</p>')
            continue
        L.append('<div class="group">')
        for c in group:
            props = f'{len(c["props"])} props' if c["props"] else '無 props'
            L.append(f'  <div class="row"><span class="label">'
                     f'<a href="{c["paths"]["preview"]}">{c["name"]}</a> '
                     f'<span class="lvl">— {c["responsibility"]}</span></span>'
                     f'<span class="lvl">{props}</span></div>')
        L.append('</div>')
    return "\n".join(L) + "\n"

def render_checks() -> str:
    """把 check-design-system.py 的 CHECKS 表渲染進 README §8。

    scripts/ 不進交付包，README 是設計端唯一看得到「實際擋了什麼」的地方。
    手寫那張表一定會過期，然後審閱會針對虛構的清單提意見。
    """
    import subprocess
    out = subprocess.run([sys.executable, str(ROOT / "scripts/check-design-system.py"), "--list"],
                         capture_output=True, text=True, check=True).stdout
    rows_ = json.loads(out)
    L = ["| # | 檢查 | 對應 |", "|---|---|---|"]
    L += [f"| {c['id']} | {c['desc']} | {c['ref']} |" for c in rows_]
    return "\n".join(L)

def inject_checks() -> bool:
    p = DS / "README.md"
    s = p.read_text()
    m = re.search(r"(<!-- checks:start[^>]*-->\n)(.*?)(<!-- checks:end -->)", s, re.S)
    if not m:
        return False
    new = m.group(1) + render_checks() + "\n" + m.group(3)
    if new == m.group(0):
        return False
    p.write_text(s[:m.start()] + new + s[m.end():])
    return True

if __name__ == "__main__":
    comps = collect()
    payload = {"generatedAt": datetime.date.today().isoformat(),
               "tokensVersion": json.loads((DS / "tokens/tokens.json").read_text())["meta"]["version"],
               "components": comps}
    new_json = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    new_html = render(comps)
    if "--check" in sys.argv:
        bad = False
        if inject_checks():
            print("✘ design-system/README.md §8 的檢查表與 CHECKS 不一致"
                  "——請跑 scripts/gen-design-index.py")
            bad = True
        for path, content in ((JSON, new_json), (HTML, new_html)):
            if not path.exists() or path.read_text() != content:
                print(f"✘ {path.relative_to(ROOT)} 與各元件 spec 不一致——請跑 scripts/gen-design-index.py")
                bad = True
        sys.exit(1 if bad else 0)
    JSON.write_text(new_json); HTML.write_text(new_html)
    inject_checks()
    print(f"✔ components.json ＋ index.html ＋ README §8 檢查表（{len(comps)} 個元件）")
