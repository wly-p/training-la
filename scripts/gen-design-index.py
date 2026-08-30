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
        "standalone": standalone_of(s1),
        "requiresContainer": requires_container(s1),
        "containerOwns": kv(s1, "容器責任"),
        "props": props_of(s2),
        "slots": inline_list(s2, "Slots"),
        "events": inline_list(s2, "事件"),
        "variants": variants_of(s3),
        "states": split(st),
        "themes": split(th),
        "confusableWith": confusable(s10),
        "dontUseFor": dont_use_for(s10),
        "composedOf": sorted(set(re.findall(r"`(TL\w+)`", s11))) or None,
        "paths": {
            "spec": f"{layer}/{name}/{name}.spec.md",
            "preview": f"{layer}/{name}/{name}.preview.html",
            "impl": kv(s1, "實作"),
        },
    }

NONE = ("（無）", "無", "N/A", "無。", "N/A。")

def standalone_of(s1):
    v = kv(s1, "獨立使用") or ""
    return False if v.startswith(("否", "**否")) else True

def requires_container(s1):
    v = kv(s1, "獨立使用") or ""
    return re.findall(r"`(TL\w+)`", v) or None

def props_of(s2):
    """名稱 | 型別 | 值域 | 必填 | 預設 | 說明

    值域比型別重要：`style: TLTagStyle` 的資訊量是零，組畫面的人要的是那 6 種 case 叫什麼。
    沒有值域就只能猜，猜錯就硬編 —— 規則一從設計端先破功。
    """
    out = []
    for r in rows(s2):
        if len(r) < 6 or r[0] in NONE or not r[0]:
            continue
        vals = [v.strip(" `") for v in re.split(r"[／/｜|、,]", r[2]) if v.strip(" `")] if r[2] else []
        out.append({"name": r[0], "type": r[1],
                    "kind": "enum" if len(vals) > 1 else None,
                    "values": vals or None,
                    "required": r[3], "default": r[4],
                    "description": r[5] if len(r) > 5 else None})
    return out

def confusable(s10):
    """第 10 節的『易混淆』對照。會搞混的時候人看的是其中一份規格，不是兩份。"""
    m = re.search(r"\*\*易混淆\*\*\s*[：:]\s*(.+)", s10)
    if not m or m.group(1).strip().startswith(NONE + ("目前沒有",)):
        return []
    return [{"name": n, "note": m.group(1).strip()} for n in re.findall(r"`(TL\w+)`", m.group(1))]

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
    """變體是物件不是字串——要能寫「變體之間哪些狀態不通用」
    （例：按鈕的 text 變體沒有 pressed 底色），那件事字串陣列裝不下。"""
    body = s3.strip()
    if not body or body.startswith(NONE):
        return []
    out = [{"name": r[0], "note": r[1] if len(r) > 1 else None}
           for r in rows(s3) if r and r[0] not in NONE]
    return out or [{"name": body.splitlines()[0], "note": None}]

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
         f'{len(comps)} 個元件　·　規則見 <a href="README.html">README</a>、'
         f'規格樣板見 <a href="_template.spec.html">規格樣板</a>　·　'
         f'token 與契約的改動見 <a href="CHANGELOG.html">CHANGELOG</a><br>'
         f'<b>這輪先讀 <a href="HANDOFF.html">HANDOFF</a></b>（跟上輪的差別、想請你看什麼）。<br>'
         f'組畫面時讀 <a href="components.json">components.json</a>（機器讀的登錄檔，'
         f'每個元件的 props／狀態／組成都在裡面），再開個別 preview。<br>'
         f'token 的實際樣子見 <a href="tokens/tokens.preview.html">tokens.preview.html</a>。</p>']
    # 按畫面找。組畫面的人的實際問題不是「列出所有原子」，是「我要做設定頁，有什麼可以用？」——
    # 依層分組是元件庫作者的視角，依畫面才是使用者的視角。兩種分組同一份 components.json 就能生成。
    scr = json.loads((DS / "screens.json").read_text())["screens"]
    L.append('<div class="kicker">按畫面找</div>')
    L.append('<div class="group">')
    any_row = False
    for sc in scr:
        used = [c for c in comps if set(c["prototypeIds"]) & set(sc["ids"])]
        if not used:
            continue
        any_row = True
        names = " · ".join(f'<a href="{c["paths"]["preview"]}">{c["name"]}</a>' for c in used)
        L.append(f'  <div class="row"><span class="label">{sc["name"]} '
                 f'<span class="lvl">{" ".join(sc["ids"])}</span></span>'
                 f'<span class="lvl">{names}</span></div>')
    if not any_row:
        L.append('  <div class="row"><span class="label lvl">（還沒有元件標到畫面）</span></div>')
    L.append('</div>')

    for layer, label in LEVELS:
        group = [c for c in comps if c["layer"] == layer]
        L.append(f'<div class="kicker">{label}（{len(group)}）</div>')
        if not group:
            L.append('<p class="note">（尚無元件）</p>')
            continue
        L.append('<div class="group">')
        for c in group:
            bits = [f'{len(c["props"])} props' if c["props"] else '無 props']
            if len(c["states"]) > 1:
                bits.append(f'{len(c["states"])} 狀態')
            # 不能單獨用的元件要一眼看得出來——40 個元件時記不住哪些需要容器
            need = ("　⚑ 需容器 " + "／".join(c["requiresContainer"])) if not c["standalone"] else ""
            spec_html = c["paths"]["spec"].replace(".md", ".html")
            L.append(f'  <div class="row"><span class="label">'
                     f'<a href="{c["paths"]["preview"]}">{c["name"]}</a> '
                     f'<span class="lvl">— {c["responsibility"]}{need}</span></span>'
                     f'<span class="lvl">{" · ".join(bits)} · '
                     f'<a href="{spec_html}">規格</a></span></div>')
        L.append('</div>')
    return "\n".join(L) + "\n"

# 三份層級 README 的骨架。手寫三份會慢慢分岔（第三輪審閱指出已經開始了），
# 而它們是設計端找東西時最先讀到的入口，所以改成生成。
LAYER_DOC = {
    "atoms": dict(
        title="L1 原子", where="`Packages/DesignSystem/Sources/DesignSystem/Atoms/`", prefix="一律 `TL` 前綴",
        define="不可再分。只收 `String` / `Int` / `Bool` / closure。",
        domain="**不得認識任何 domain 型別**",
        extra="原子沒有第 2 節的 slots、也沒有第 11 節組成；其餘各節都要填。\n\n"
              "原子幾乎都**自己不完整** —— 必須放在某個容器裡才成立。"
              "規格第 1 節的「獨立使用」與「容器責任」兩格就是為了這件事，一定要填。"),
    "molecules": dict(
        title="L2 分子", where="`Packages/DesignSystem/Sources/DesignSystem/Molecules/`", prefix="一律 `TL` 前綴",
        define="由原子組成，仍與 domain 無關。",
        domain="**不得認識任何 domain 型別**",
        extra="規格第 11 節要列出它由哪些 L1 組成 —— `make lint` 會檢查那些原子真的在庫裡，"
              "而且會擋「preview 出現不屬於任何 L1 的裸樣式」。\n\n"
              "preview 需要假資料時，**不要用真的運動名稱**（臥推、組數…）。"
              "那是最順手的假資料，但寫下去的那一刻 L2 就認識 domain 了。機器檢查會擋。"),
    "organisms": dict(
        title="L3 有機體", where="各 package 的 `Presentation/Components/`", prefix="**無**前綴",
        define="綁自己 package 的 model，會出現在多個畫面。",
        domain="可以 import domain 型別 —— 這正是它留在 package 裡的原因",
        extra="實作檔留在 package 裡，但 `X.spec.md` 與 `X.preview.html` 集中放這裡、"
              "preview 用假資料 —— 否則設計端拿不到完整的一包。\n\n"
              "判斷法：**這個元件需要 import 某個 package 的 model 嗎？**"
              "需要 → L3；不需要 → 往 L1／L2 移。"),
}

def render_layer_readme(layer: str) -> str:
    d = LAYER_DOC[layer]
    return f"""# {d['title']}

{d['define']}{d['domain']}。住 {d['where']}，{d['prefix']}。

每個元件一個目錄，含 `X.spec.md` 與 `X.preview.html`（實作檔的位置由 spec 第 1 節指出）。
規格樣板見 [`../_template.spec.md`](../_template.spec.md)，規則見 [`../README.md`](../README.md)。

{d['extra']}
"""

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
    # 編號是永久 id（CHANGELOG 與 README 正文都用它指稱），所以輸出要依 id 排序，
    # 不能照宣告順序——否則表格看起來像壞掉的，而這張表的價值全在「可以相信它」。
    L += [f"| {c['id']} | {c['desc']} | {c['ref']} |" for c in sorted(rows_, key=lambda c: c['id'])]
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
        for layer in LAYER_DOC:
            if (DS / layer / "README.md").read_text() != render_layer_readme(layer):
                print(f"✘ design-system/{layer}/README.md 與骨架不一致——請跑 scripts/gen-design-index.py")
                bad = True
        for path, content in ((JSON, new_json), (HTML, new_html)):
            if not path.exists() or path.read_text() != content:
                print(f"✘ {path.relative_to(ROOT)} 與各元件 spec 不一致——請跑 scripts/gen-design-index.py")
                bad = True
        sys.exit(1 if bad else 0)
    JSON.write_text(new_json); HTML.write_text(new_html)
    for layer in LAYER_DOC:
        (DS / layer / "README.md").write_text(render_layer_readme(layer))
    inject_checks()
    print(f"✔ components.json ＋ index.html ＋ README §8 檢查表（{len(comps)} 個元件）")
