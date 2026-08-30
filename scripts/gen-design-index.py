#!/usr/bin/env python3
"""從各元件的 spec.md 抽出 components.json ＋ index.html。

**不是新的真相來源**——每個欄位都來自 spec 十二節裡已經有的資訊。
設計端要組畫面時讀這一份就知道有哪些元件、各自收什麼 props，
不必逐份開 40 個 spec（開了也容易猜錯 props，然後被迫硬編，
規則一就從設計端先破功）。
"""
import json, pathlib, re, sys

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
            s1, s2, s4, s11 = (sect(md, x) for x in ("1 身分", "2 介面", "4 狀態 states ★", "11 組成 ★"))
            props = [{"name": r[0], "type": r[1], "required": r[2], "default": r[3]}
                     for r in rows(s2) if len(r) >= 4 and r[0] not in ("（無）",)]
            st = re.search(r"<!--\s*states:\s*([^>]+?)\s*-->", s4)
            th = re.search(r"<!--\s*themes:\s*([^>]+?)\s*-->", s4)
            split = lambda m: [x.strip() for x in m.group(1).split(",") if x.strip()] if m else []
            comps.append({
                "name": cdir.name,
                "level": label.split()[0],
                "layer": layer,
                "responsibility": kv(s1, "職責"),
                "prototypeIds": kv(s1, "原型 id"),
                "props": props,
                "states": split(st),
                "themes": split(th),
                "composedOf": sorted(set(re.findall(r"`(TL\w+)`", s11))) or None,
                "paths": {
                    "spec": f"{layer}/{cdir.name}/{cdir.name}.spec.md",
                    "preview": f"{layer}/{cdir.name}/{cdir.name}.preview.html",
                    "impl": kv(s1, "實作"),
                },
            })
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
         f'規格樣板見 <a href="_template.spec.md">_template.spec.md</a><br>'
         f'先讀 <a href="components.json">components.json</a>（機器讀的登錄檔，'
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

if __name__ == "__main__":
    comps = collect()
    payload = {"tokensVersion": json.loads((DS / "tokens/tokens.json").read_text())["meta"]["version"],
               "components": comps}
    new_json = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    new_html = render(comps)
    if "--check" in sys.argv:
        bad = False
        for path, content in ((JSON, new_json), (HTML, new_html)):
            if not path.exists() or path.read_text() != content:
                print(f"✘ {path.relative_to(ROOT)} 與各元件 spec 不一致——請跑 scripts/gen-design-index.py")
                bad = True
        sys.exit(1 if bad else 0)
    JSON.write_text(new_json); HTML.write_text(new_html)
    print(f"✔ components.json ＋ index.html（{len(comps)} 個元件）")
