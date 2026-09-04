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

_TOK    = json.loads((DS / "tokens/tokens.json").read_text())
PRIM_C  = _TOK["primitive"]["color"]
SEM_NAMES = list(_TOK["semantic"]["color"])
TYPE_ROLES = _TOK["type"]["roles"]
LEGACY  = [k for k in json.loads((DS / "tokens/_legacy-aliases.json").read_text()) if k != "note"]

def kebab(x):
    return "".join("-" + c.lower() if c.isupper() else c for c in x)

SECTIONS = ["1 身分", "2 介面", "3 變體", "4 狀態", "5 度量與行為", "6 配色",
            "7 用法與禁用法", "8 變更紀錄"]
# 量的是**字面值**，不是 API 用法：`.font(.system(size: TLIcon.sm))` 已經吃 token 了，
# 不該被算成違規（第一次把 Settings 推到 0 時抓到的誤判）。所以每一條都要求後面接數字。
LITERAL_STYLE = re.compile(
    r"\.font\(\.system\(size: ?[0-9]"
    r"|\.font\(\.custom\([^,]*, ?size: ?[0-9]"
    # `TLFont.zh(15.5)` 長得像吃了 token，其實是字面字級——**它一路躲過了 ratchet**。
    # 設定頁被宣告成「字面樣式 0」的那一刻，SettingsView 裡就有一個 13。
    # 2026-08-31 補上，基線跟著重設。
    r"|TLFont\.(?:zh|display)\( ?[0-9]"
    # 系統字級（.footnote/.caption/.headline…）連數字都沒有，前兩版的 regex 完全看不到它們。
    # 它們不只是「另一種寫法」——系統字級**跟著 Dynamic Type 縮放**，等於一套平行的字級系統。
    # 2026-09-04 補上，這是 ratchet 的第三個洞。
    r"|\.font\(\.(?:footnote|caption2?|subheadline|headline|title[23]?|body|callout|largeTitle)\b"
    # `cornerRadius` 只認得 RoundedRectangle 的那一個；UnevenRoundedRectangle 的四個角
    # （bottomTrailingRadius…）逃掉了。2026-09-04 補。
    r"|[a-zA-Z]*[Rr]adius: ?[0-9]"
    r"|\.padding\((?:\.[a-z]+, )?[0-9]"
    # ⚠ 只寫 `width|height` 會漏掉 minWidth／maxHeight／idealWidth——大小寫敏感，
    # 而那些正是「固定尺寸」最常見的寫法。2026-09-04 補（ratchet 的第四個洞）。
    r"|\.frame\(.*?(?:[Ww]idth|[Hh]eight): ?[0-9]"
    # spacing 也是樣式。`spacing: 0` 不算——那是「不要間距、讓子項自己決定」的結構選擇，
    # 不是設計值，強迫它吃 token 只會逼出一個 TLSpace.none = 0。
    r"|spacing: ?[1-9]")
FEATURE_MODULES = ("Spec", "Plan", "Training", "History", "Settings", "Ability", "Reminders")

# 這張表是 README §8 檢查清單的**唯一來源** —— scripts/ 不進交付包，
# 設計端只看得到 README，所以那份表由 gen-design-index.py 從這裡生成，不能手改。
CHECKS = {
    1:  ("每個元件有 spec ＋ preview，spec 十二節齊全，實作檔存在", "§6"),
    2:  ("Swift 側一個檔一個 public 元件", "§7.1"),
    3:  ("spec 宣告的 props 與 `init` 參數一致 —— 兩個方向都擋："
         "宣告了 init 沒有的 prop、以及**宣告無 props 但 init 其實收參數**", "§6.2"),
    4:  ("`states` 每個都有對應的 `data-state`、`themes` 每個都有對應的 `data-theme`；"
         "主題不得混進 states", "§6.4、§7.4"),
    6:  ("spec 與 preview 內零字面色值（**所有檔案，無豁免**）；preview 無外部請求", "§6.6、§7.2"),
    14: ("**元件 preview 與 examples** 內零字面尺寸。豁免只適用設計系統自身的展示頁"
         "（`tokens/tokens.preview.html`），按路徑判定不靠語意", "§7.3"),
    15: ("`examples/` 的整頁組合只用元件與 token —— 它是畫面的規格，不是另一份設計稿", "§6.5"),
    16: ("`components.preview.css` 與元件庫成對：每個元件有且僅有一段 `.tl-<name>`，"
         "且沒有孤兒段落。**兩份實作的一致性擋不了**（要跨語言比對），"
         "但孤兒與遺漏擋得了，而那是實際會發生的兩種漂移", "§7.7"),
    9:  ("preview 用到的 `var(--…)` 都在 `tokens.css` 或 `preview.css` 裡定義", "§5"),
    10: ("preview 用到的字都在子集字型裡（缺字會靜默掉回系統字型）", "§7"),
    11: ("第 11 節宣告的組成元件真的存在於元件庫", "§6.11"),
    12: ("文件裡提到的 token 名都存在於 `tokens.json`", "§5"),
    13: ("L1／L2 的 preview 不出現 domain 詞彙（Exercise／Workout／組數…）"
         "—— 假資料最順手的來源就是真的運動名稱，那一刻就違反了規則三", "§4 規則三、§7.5"),
    7:  ("Presentation 層字面樣式**不得增加**（ratchet，不是硬門檻）", "§4 規則一"),
    8:  ("`DesignSystem` 未 import 任何功能 package", "§4 規則三"),
    17: ("同一個字型家族內，兩個**不同**的字級值差距不得小於 1（同值的兩個角色是允許的）", "§5"),
    18: ("`DesignSystem` 零邏輯：不得持有狀態、不得格式化／日期運算；`GeometryReader` 走登記制", "§4 規則二之二"),
    19: ("畫面檔自己組的 view 成員**不得增加**（ratchet）——應用層是排列不是定義", "§4 規則一"),
    5:  ("生成物與來源一致：`tokens.json` → Swift／CSS；各 spec → `components.json`／`index.html`", "§5、§6"),
}

DEFINED_VARS = set()
for _css in ("tokens/tokens.css", "preview.css"):
    DEFINED_VARS |= set(re.findall(r"^\s*(--[A-Za-z0-9-]+):", (DS / _css).read_text(), re.M))

errs, warns = [], []
def err(c, m): errs.append(f"✘ [檢查 {c}] {m}")

# 檢查 9 原本只看 preview.html，但**壞掉的 var 在 CSS 檔裡一樣是靜默的**：
# `width: var(--icon-in-check-circle)` 打錯名字不會報錯，只會渲染成無效值。
# 這兩個名字錯了不知道多久，設計端看到的勾號與圓鈕圖示一直是自動尺寸。
for _css in ("preview.css", "components.preview.css", "_controls/controls.preview.css"):
    _p = DS / _css
    if not _p.exists():
        continue
    _body = _p.read_text()
    _local = set(re.findall(r"^\s*(--[A-Za-z0-9-]+):", _body, re.M))
    for _v in sorted(set(re.findall(r"var\((--[A-Za-z0-9-]+)\)", _body))):
        if _v not in DEFINED_VARS and _v not in _local:
            err(9, f"{_css}：用了未定義的 token `var({_v})`——CSS 裡打錯 var 名字是靜默失效")

def components():
    for layer in ("atoms", "molecules", "organisms"):
        d = DS / layer
        if d.is_dir():
            for c in sorted(p for p in d.iterdir() if p.is_dir()):
                yield layer, c

# 控制項（DesignControls）不進交付包，但**它們是真的元件**：L3 組合得到它們。
# 檢查 11 要認得，否則規格只能把組成寫得含糊（或乾脆不寫）——
# 那正是這條檢查要擋的東西。
def control_names():
    d = DS / "_controls"
    return {c.name for c in d.iterdir() if c.is_dir()} if d.is_dir() else set()

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
            # L3 有機體住在各自 package 的 Presentation/Components/，不需要 public
            # （沒有跨 package 使用），而且多半用 memberwise init。
            # 檢查 2／3 原本是為 L1／L2 寫的，這裡放寬成「頂層型別」與「memberwise 也算」。
            kw = "" if layer == "organisms" else "public "
            pub = re.findall(rf"^{kw}(?:struct|enum|final class|class|protocol) (\w+)", src, re.M)
            if len(pub) != 1:
                err(2, f"{m.group(1)}：一個檔應該只有一個元件，找到 {len(pub)} 個 {pub}")
            # §2 props ↔ init 參數
            #
            # @ViewBuilder 參數是 **Slot 不是 prop**，規格裡也是寫在「Slots」那一行、
            # 不在 props 表格裡。兩者要分開比對，否則每個有 slot 的元件都會誤報。
            props = section(spec, "2 介面") or ""
            declared = [x for x in re.findall(r"^\|\s*`?(\w+)`?\s*\|", props, re.M)
                        if x not in ("名稱",)]
            # Slots 的宣告可以跨行（三個 slot 各佔一行是常見的），所以讀到下一個 ** 標記為止
            slot_line = re.search(r"\*\*Slots\*\*.*?(?=\n\*\*|\n##|\Z)", props, re.S)
            declared_slots = re.findall(r"`(\w+)`", slot_line.group(0)) if slot_line else []

            # 掃**所有**頂層 init：多個 init 是常見的（便利建構子、有無操作的兩種列…），
            # 只看第一個會讓後面那些 init 才有的 prop 全部誤報。
            #
            # 兩個必須注意的地方（都是被真元件抓出來的）：
            #   1. 參數本身可能含括號（`format: @escaping (Double) -> String`），
            #      所以要**配對括號**而不是抓到第一個 `)` 為止
            #   2. 巢狀型別（`QuickAction`、`Option`）自己的 init 縮排更深，不算這個元件的 prop
            def top_level_inits(text):
                for m in re.finditer(r"^ {4}(?:public )?init\(", text, re.M):  # noqa: B023
                    i, depth = m.end() - 1, 0
                    for j in range(i, len(text)):
                        if text[j] == "(":
                            depth += 1
                        elif text[j] == ")":
                            depth -= 1
                            if depth == 0:
                                yield text[i + 1:j]
                                break
            raw = " , ".join(top_level_inits(src))
            if not raw.strip() and layer == "organisms":
                # memberwise init：用頂層的 let/var 宣告當 props（順序即參數順序）
                # 只取 stored properties：`var body: some View` 是 computed，不是 prop
                raw = " , ".join(
                    f"{n}:" for n in re.findall(r"^ {4}(?:let|var) (\w+): [^\n{]+$", src, re.M))
            all_params = re.findall(r"(?:^|,)\s*(?:@\w+\s+)?(?:\w+\s+)?(\w+)\s*:", raw)
            slots = re.findall(r"@ViewBuilder\s+(?:\w+\s+)?(\w+)\s*:", raw)
            actual = [x for x in all_params if x not in slots]

            if not declared and actual:
                err(3, f"{name}：規格說無 props，但 init 有非 slot 參數 {actual}")
            for d in declared:
                if d not in actual:
                    err(3, f"{name}：規格宣告的 prop `{d}` 不在 init 參數裡 {actual}")
            for sl in slots:
                if sl not in declared_slots:
                    err(3, f"{name}：init 有 slot `{sl}`，但規格第 2 節的 Slots 沒宣告它")
            # 反向：init 有但規格沒寫的 prop。**這個方向才是設計端會被騙的方向**——
            # 沒寫在規格裡的 prop 等於不存在，組畫面的人不知道可以傳它，只好繞路硬編。
            for a in dict.fromkeys(actual):
                if a not in declared:
                    err(3, f"{name}：init 有 prop `{a}`，但規格第 2 節沒宣告它"
                           f"——沒寫在規格裡的 prop 等於不存在")

    # §4 states ↔ preview 的 data-state；themes ↔ data-theme
    ms = re.search(r"<!--\s*states:\s*([^>]+?)\s*-->", spec)
    if not ms:
        err(4, f"{name}.spec.md：第 4 節缺機器可讀的 `<!-- states: … -->` 宣告")
    else:
        want = [x.strip() for x in ms.group(1).split(",") if x.strip()]
        have = set(re.findall(r'data-state="([^"]+)"', prev))
        for x in want:
            if x in ("light", "dark"):
                err(4, f"{name}：`{x}` 是主題維度不是狀態，要放進 `<!-- themes: … -->`"
                       f"——混進 states 會讓這條檢查通過得沒有意義")
            elif x not in have:
                err(4, f"{name}：規格宣告狀態 `{x}`，preview 沒有對應的 data-state")

    mt = re.search(r"<!--\s*themes:\s*([^>]+?)\s*-->", spec)
    if not mt:
        err(4, f"{name}.spec.md：第 4 節缺 `<!-- themes: … -->` 宣告")
    else:
        want = [x.strip() for x in mt.group(1).split(",") if x.strip()]
        have = set(re.findall(r'data-theme="([^"]+)"', prev))
        for x in want:
            if x not in have:
                err(4, f"{name}：規格宣告主題 `{x}`，preview 沒有對應的 data-theme")

    # §6 零字面色值（spec 與 preview）
    for label, txt in ((f"{name}.spec.md", spec), (f"{name}.preview.html", prev)):
        for lit in re.findall(r"#[0-9a-fA-F]{3,8}\b|rgba?\([^)]*\)", txt):
            err(6, f"{label}：出現字面色值 `{lit}`，只准用語意 token / var(--…)")

    # preview 自足
    for u in re.findall(r'(?:src|href)="(https?:)?//[^"]+"', prev):
        err(6, f"{name}.preview.html：有外部請求，preview 必須自足")

    # preview 用到的 CSS 變數必須有定義（打錯名字會靜默渲染成空值）
    for v in sorted(set(re.findall(r"var\((--[A-Za-z0-9-]+)\)", prev))):
        if v not in DEFINED_VARS:
            err(9, f"{name}.preview.html：用了未定義的 token `var({v})`")

    # §11 組成宣告的元件要真的存在
    if layer != "atoms":
        comp = section(spec, "1 身分") or ""
        for ref in re.findall(r"`(TL\w+)`", comp):
            if not any(c.name == ref for _, c in components()) and ref not in control_names():
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

# ── 19：畫面檔不得自己長元件（ratchet，正典 §4 規則一）──────────────
#
# 檢查 7 量的是**字面樣式**，不是**元件定義**。一個畫面檔可以一個字面值都沒有，
# 卻仍然自己組了 26 個 view——那正是規則一要擋的東西，而它一直沒有數字。
#
# 量法：畫面檔（Presentation 下、不在 Components/ 裡）的頂層 `some View` 成員，
# 扣掉 `body` 本身（那是畫面，不是元件）。
#
# 跟檢查 7 一樣走 ratchet 而不是硬門檻：畫面把自己拆成幾段是可讀性的選擇，
# 硬性歸零會逼出一個 800 行的 body。**擋的是「又長出新的」。**
VIEW_MEMBER = re.compile(
    r"^\s*(?:@ViewBuilder\s+)?(?:private\s+)?(?:@ViewBuilder\s+)?"
    r"(?:var|func)\s+(\w+)[^\n]*?some View", re.M)

screen_counts = {}
for f in sorted(PKG.rglob("*.swift")):
    if ".build" in f.parts or "Presentation" not in str(f):
        continue
    if "/Components/" in str(f):        # L3 本來就是元件，不算畫面
        continue
    names = [n for n in VIEW_MEMBER.findall(f.read_text()) if n != "body"]
    if names:
        screen_counts[f.name] = len(names)

SCREEN_BASE = DS / ".screen-baseline.json"

if "--list" in sys.argv:
    print(json.dumps([{"id": k, "desc": v[0], "ref": v[1]} for k, v in CHECKS.items()],
                     ensure_ascii=False))
    sys.exit(0)

if "--update-baseline" in sys.argv:
    BASE.write_text(json.dumps(counts, indent=2, sort_keys=True) + "\n")
    SCREEN_BASE.write_text(json.dumps(screen_counts, indent=2, sort_keys=True) + "\n")
    print(f"✔ 基線已更新：{counts}（總計 {sum(counts.values())}）")
    print(f"✔ 畫面基線已更新：{len(screen_counts)} 個畫面檔、"
          f"自己組的 view 共 {sum(screen_counts.values())} 個")
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

# ── 10：preview 用到的中文字都要在子集字型裡（缺字是靜默失效）──────
mani = DS / "fonts" / "subset-chars.txt"
if mani.exists():
    have = set(mani.read_text())
    used = set()
    for f in DS.rglob("*.html"):
        used |= set(f.read_text())
    missing = {ch for ch in used - have if ch.isprintable() and not ch.isspace()}
    if missing:
        err(10, f"preview 用到 {len(missing)} 個不在子集字型裡的字（{''.join(sorted(missing)[:12])}…）"
                f"——跑 make preview-font 重生，否則設計端會看到方框")

# ── 13：L1／L2 的 preview 不得出現 domain 詞彙 ─────────────────────
# 為什麼會發生：分子的 preview 需要假資料，而最順手的假資料就是真的運動名稱。
# 「臥推 60kg × 8」寫起來毫不費力，但那一刻 L2 就認識 domain 了（規則三）。
# 詞表隨階段成長——撞到新的 domain 名詞就加進來。
DOMAIN_WORDS = [
    "Exercise", "Workout", "Template", "Rotation", "Program", "PlanWorkout", "AbilityValue",
    "臥推", "深蹲", "硬舉", "引體", "划船", "肩推", "二頭", "三頭", "棒式",
    "課表", "範本", "循環", "訓練日", "組數", "次數", "熱身組", "能力值", "最大重量",
    # 「動作」刻意不列：在這個 app 它同時是 domain 名詞（exercise）與 UI 名詞（action），
    # 留著會把「文字動作」這種正常敘述判成違規。改用不會歧義的詞就夠擋住真正的問題。
]
for layer in ("atoms", "molecules"):
    for f in (DS / layer).rglob("*.preview.html"):
        body = f.read_text()
        hits = sorted({w for w in DOMAIN_WORDS if w in body})
        if hits:
            err(13, f"{f.relative_to(DS)}：L1／L2 的 preview 出現 domain 詞彙 {hits}"
                    f"——改用與 domain 無關的假資料")

# ── 14／15：元件 preview 與 examples 不得有字面尺寸或未定義 token ──────
# 豁免是白名單而不是判斷題：「這段算不算展示骨架」人在趕的時候一定會判成算。
# examples/ 是整頁組合，代表「這個畫面長什麼樣」。它是畫面的規格、不是另一份設計稿，
# 所以只准用元件與 token——一旦允許字面值，它會慢慢長成第三份真相。
SCAFFOLD_OK = ("tokens/tokens.preview.html", "index.html")
LITERAL_SIZE = re.compile(r":\s*-?\d+(?:\.\d+)?(?:px|pt)\b"
                          r"|\b(?:width|height|stroke-width)=\"-?\d")
n_example = 0
for layer in ("atoms", "molecules", "organisms", "examples"):
    d = DS / layer
    if not d.is_dir():
        continue
    for f in sorted(list(d.rglob("*.preview.html")) + list(d.rglob("*.example.html"))):
        rel = str(f.relative_to(DS))
        if rel.startswith(SCAFFOLD_OK):
            continue
        body = f.read_text()
        is_example = layer == "examples"
        n_example += is_example
        cid = 15 if is_example else 14
        for lit in sorted(set(LITERAL_SIZE.findall(body)))[:5]:
            err(cid, f"{rel}：出現字面尺寸 `{lit.strip()}`，一律用 var(--…)"
                     f"（豁免只給設計系統自身的展示頁，按路徑判定）")
        if is_example:
            for v in sorted(set(re.findall(r"var\((--[A-Za-z0-9-]+)\)", body))):
                if v not in DEFINED_VARS:
                    err(15, f"{rel}：用了未定義的 token `var({v})`")

# ── 16：components.preview.css 與元件庫成對 ────────────────────────
# preview.css 原本裝的是展示骨架（.group/.row/.kicker），但元件的 CSS 鏡像
# 慢慢混了進去——那些是元件的**第二份實作**，沒有規格、沒有狀態窮舉、沒有版本紀錄。
# 19 個元件時看得住，40 個時會長成一份平行的設計系統。
#
# 兩份實作的一致性沒辦法自動驗（要跨語言比對，不值得做），但**孤兒與遺漏**擋得了，
# 而那正是實際會發生的兩種漂移。
def kebab_name(n):
    out = []
    for i, c in enumerate(n):
        if c.isupper() and i:
            out.append("-")
        out.append(c.lower())
    return "".join(out)

CPCSS = DS / "components.preview.css"
if CPCSS.exists():
    css_body = CPCSS.read_text()
    # 每一段由 `/* TLXxx */` 標頭起算
    # 純 `/* Name */` 的標頭才算元件段落（帶說明文字的是註解，例如骨架那幾段）。
    sections = re.findall(r"^/\* ([A-Za-z]\w*) \*/\s*$", css_body, re.M)
    lib = {c.name for _, c in components()}

    for sec in sections:
        if sec not in lib:
            err(16, f"components.preview.css：`{sec}` 段落沒有對應的元件（孤兒樣式）")
    dupes = {x for x in sections if sections.count(x) > 1}
    for dup in sorted(dupes):
        err(16, f"components.preview.css：`{dup}` 有多個段落，一個元件只該有一段")

    # preview 用到 .tl-x 卻沒有定義。
    # 控制項（DesignControls）的 CSS 在 _controls/ 底下，不進交付包——
    # example 引用得到它們（畫面裡本來就會放控制項），但它們不算元件庫的一部分。
    defined_classes = set(re.findall(r"\.(tl-[a-z0-9_-]+)", css_body))
    ctrl_css = DS / "_controls/controls.preview.css"
    control_classes = (set(re.findall(r"\.(tl-[a-z0-9_-]+)", ctrl_css.read_text()))
                       if ctrl_css.exists() else set())
    for layer in ("atoms", "molecules", "organisms", "examples"):
        d = DS / layer
        if not d.is_dir():
            continue
        for f in sorted(list(d.rglob("*.preview.html")) + list(d.rglob("*.example.html"))):
            body = f.read_text()
            local = set(re.findall(r"\.(tl-[a-z0-9_-]+)", body))  # 本地 <style> 也算
            for cls in sorted(set(re.findall(r"class=\"([^\"]*)\"", body))):
                for one in cls.split():
                    if not one.startswith("tl-") or one in defined_classes or one in local:
                        continue
                    if one in control_classes:
                        # 元件 preview 不該用到控制項——那代表分層錯了
                        if layer != "examples":
                            err(16, f"{f.relative_to(DS)}：元件 preview 用了控制項的 `.{one}`。"
                                    f"控制項有狀態與計算，不該出現在元件的 preview 裡")
                        continue
                    err(16, f"{f.relative_to(DS)}：用了 `.{one}` 但 components.preview.css 沒有定義")

# ── 12：文件提到的 token 名都要真的存在 ───────────────────────────
# 抓「token 被刪／改名，但正典或規格還在講它」——README 是正典，
# 它的 token 名寫錯比生成物寫錯更容易誤導人。
known = set(SEM_NAMES) | set(LEGACY) | {
    f"{scale}-{k}" for scale, ramp in PRIM_C.items() if isinstance(ramp, dict) for k in ramp}
known |= {kebab(n) for n in list(SEM_NAMES) + list(LEGACY)}
for doc in [DS / "README.md"] + list(DS.rglob("*.spec.md")):
    body = doc.read_text()
    for m in re.finditer(r"`(surface-[a-z-]+|text-[a-z-]+|border-[a-z-]+|action-[a-z-]+"
                         r"|accent-on-[a-z-]+|danger-[a-z-]+|category-[a-z-]+)`", body):
        if m.group(1) not in known:
            err(12, f"{doc.relative_to(ROOT)}：提到不存在的 token `{m.group(1)}`"
                    f"——被刪掉或改名了，文件沒跟上")

# ── 17：字級尺度的最小間距 ────────────────────────────────────────
# 設計端拍板的規則：同一個家族裡兩個**不同**的值差距不得小於 1。
# 同值的兩個角色是允許的——`rowTitle` 與 `buttonLabel` 都是 15，它們表達的是
# 「未來會分開走」而不是「現在不一樣大」。會被擋掉的是 15／15.5 這種 0.5 的漂移，
# 也就是這一輪清掉的那 15 處。
# `paired` 的角色不算尺度階（buttonLabelSmall 之於 buttonLabel，照 icon inXxx 的模式）。
# 例外一律登記在 tokens.json 的 _scaleExceptions，並且每跑一次就印一次——
# 靜默放行的例外會變成永久的例外。
EXC = {(e["family"], tuple(e["pair"])): e["reason"]
       for e in _TOK["type"].get("_scaleExceptions", [])}
by_family = {}
for _n, _r in TYPE_ROLES.items():
    if _r.get("paired"):
        continue
    by_family.setdefault(_r.get("family", "zh"), {}).setdefault(_r["size"], []).append(_n)
for _fam, _sizes in by_family.items():
    _vals = sorted(_sizes)
    for _a, _b in zip(_vals, _vals[1:]):
        if _b - _a >= 1:
            continue
        who = f"{_a}（{'／'.join(_sizes[_a])}）與 {_b}（{'／'.join(_sizes[_b])}）"
        if (_fam, (_a, _b)) in EXC:
            warns.append(f"⚠ [檢查 17] 已登記的例外：{_fam} 家族 {who} 只差 {round(_b - _a, 2)}"
                         f"——{EXC[(_fam, (_a, _b))]}")
        else:
            err(17, f"type 家族 `{_fam}`：{who} 只差 {round(_b - _a, 2)}——"
                    f"同一家族裡不同的值至少要差 1，0.5 的差在螢幕上不存在，只會變成漂移。"
                    f"真的要留就登記進 tokens.json 的 _scaleExceptions 並寫理由")

# ── 18：DesignSystem 零邏輯（正典 §4 規則二之二）────────────────────
#
# 這條規則寫在正典裡，但一直**沒有任何檢查在擋**——靠的是慣例與 package 切分。
# 這一輪已經證明過兩次「沒有檢查在擋的規則會漂」（ratchet 漏算字級、CSS 的 var 名字打錯），
# 所以補上。
#
# 界線照正典：**不得持有或改變自己的狀態、不得從資料算出設計值**（格式化、日期運算）。
# `@Binding` 與 closure prop 是資料通道，可以留。
#
# `GeometryReader` 是灰色地帶：進度條把 ratio 映射成寬度**就是它的呈現本身**，
# 那是佈局不是業務邏輯。所以走登記制——登記過的放行但每次都印出來，
# 沒登記的是硬錯。靜默放行的例外會變成永久的例外。
STATE_PAT = re.compile(r"@State\b|@FocusState\b|@StateObject\b|@Observable\b|: *ObservableObject\b")
COMPUTE_PAT = re.compile(r"String\(format:|DateFormatter|NumberFormatter|Calendar\(|\.formatted\(")
GEOMETRY_ALLOW = json.loads((DS / "logic-exceptions.json").read_text())["geometryReader"] \
    if (DS / "logic-exceptions.json").exists() else {}

for f in sorted((PKG / "DesignSystem").rglob("*.swift")):
    if ".build" in f.parts:
        continue
    rel = str(f.relative_to(ROOT))
    body = f.read_text()
    for m in STATE_PAT.finditer(body):
        err(18, f"{f.name}：元件庫不得持有狀態（`{m.group(0)}`）——"
                f"有狀態的是**控制項**，住 DesignControls")
    for m in COMPUTE_PAT.finditer(body):
        err(18, f"{f.name}：元件庫不得計算（`{m.group(0)}`）——"
                f"格式化與日期運算屬於呼叫端，元件只收算好的 `Text`")
    if "GeometryReader" in body:
        why = GEOMETRY_ALLOW.get(f.name)
        if why:
            warns.append(f"⚠ [檢查 18] 已登記的 GeometryReader：{f.name}——{why}")
        else:
            err(18, f"{f.name}：用了 `GeometryReader`。依可用空間做比例佈局是允許的，"
                    f"但要登記進 design-system/logic-exceptions.json 並寫理由")

# ── 19：畫面檔不得自己長元件（ratchet，正典 §4 規則一）──────────────
_sbase = json.loads(SCREEN_BASE.read_text()) if SCREEN_BASE.exists() else {}
for _f, _n in screen_counts.items():
    _b = _sbase.get(_f)
    if _b is None:
        err(19, f"{_f}：自己組了 {_n} 個 view 但基線沒有這個檔，跑 --update-baseline")
    elif _n > _b:
        err(19, f"{_f}：畫面自己組的 view 從 {_b} 增加到 {_n}——"
                f"應用層是**排列**不是定義（正典 §4 規則一）。"
                f"要新的東西就抽成 L3 放 Presentation/Components/")
    elif _n < _b:
        warns.append(f"↓ {_f}：{_b} → {_n} 個 view，記得跑 --update-baseline")

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
print(f"✔ 元件庫契約通過（{n_comp} 個元件、{n_example} 份 example；"
      f"Presentation 字面樣式 {tot} 處，未超過基線）")
