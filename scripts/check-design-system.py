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
LEGACY  = [k for k in json.loads((DS / "tokens/_legacy-aliases.json").read_text()) if k != "note"]

def kebab(x):
    return "".join("-" + c.lower() if c.isupper() else c for c in x)

SECTIONS = ["1 身分", "2 介面", "3 變體", "4 狀態", "5 度量", "6 配色",
            "7 文字行為", "8 動態", "9 無障礙", "10 用法與禁用法", "11 組成", "12 變更紀錄"]
# 量的是**字面值**，不是 API 用法：`.font(.system(size: TLIcon.sm))` 已經吃 token 了，
# 不該被算成違規（第一次把 Settings 推到 0 時抓到的誤判）。所以每一條都要求後面接數字。
LITERAL_STYLE = re.compile(
    r"\.font\(\.system\(size: ?[0-9]"
    r"|\.font\(\.custom\([^,]*, ?size: ?[0-9]"
    r"|cornerRadius: ?[0-9]"
    r"|\.padding\((?:\.[a-z]+, )?[0-9]"
    r"|\.frame\(.*?(?:width|height): ?[0-9]"
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
    9:  ("preview 用到的 `var(--…)` 都在 `tokens.css` 或 `preview.css` 裡定義", "§5"),
    10: ("preview 用到的字都在子集字型裡（缺字會靜默掉回系統字型）", "§7"),
    11: ("第 11 節宣告的組成元件真的存在於元件庫", "§6.11"),
    12: ("文件裡提到的 token 名都存在於 `tokens.json`", "§5"),
    13: ("L1／L2 的 preview 不出現 domain 詞彙（Exercise／Workout／組數…）"
         "—— 假資料最順手的來源就是真的運動名稱，那一刻就違反了規則三", "§4 規則三、§7.5"),
    7:  ("Presentation 層字面樣式**不得增加**（ratchet，不是硬門檻）", "§4 規則一"),
    8:  ("`DesignSystem` 未 import 任何功能 package", "§4 規則三"),
    5:  ("生成物與來源一致：`tokens.json` → Swift／CSS；各 spec → `components.json`／`index.html`", "§5、§6"),
}

DEFINED_VARS = set()
for _css in ("tokens/tokens.css", "preview.css"):
    DEFINED_VARS |= set(re.findall(r"^\s*(--[a-z0-9-]+):", (DS / _css).read_text(), re.M))

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
                for m in re.finditer(r"^ {4}(?:public )?init\(", text, re.M):
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
    for v in sorted(set(re.findall(r"var\((--[a-z0-9-]+)\)", prev))):
        if v not in DEFINED_VARS:
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

if "--list" in sys.argv:
    print(json.dumps([{"id": k, "desc": v[0], "ref": v[1]} for k, v in CHECKS.items()],
                     ensure_ascii=False))
    sys.exit(0)

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
            for v in sorted(set(re.findall(r"var\((--[a-z0-9-]+)\)", body))):
                if v not in DEFINED_VARS:
                    err(15, f"{rel}：用了未定義的 token `var({v})`")

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
