#!/usr/bin/env python3
"""design-system/tokens/tokens.json → DesignTokens.swift ＋ tokens.css

token 的唯一來源是 tokens.json。這支腳本的兩個產物都不可手改——
`make lint` 會檢查它們與來源一致（scripts/check-tokens.sh）。

深色目前是淺色的複製。C6a 換上真的色階時，只需要改 tokens.json 的 dark 值，
以及把這裡的 Swift 語意色改成 dynamic 形式（#if canImport(UIKit) 的 traits 分支）——
**不需要動任何元件或畫面**，因為呼叫端拿到的型別仍然是 Color。
"""
import json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC  = ROOT / "design-system/tokens/tokens.json"
SWIFT= ROOT / "Packages/DesignSystem/Sources/DesignSystem/DesignTokens.swift"
CSS  = ROOT / "design-system/tokens/tokens.css"

D = json.loads(SRC.read_text())
PRIM, SEM = D["primitive"]["color"], D["semantic"]["color"]
BASE = D["primitive"]["scaleBase"]

_B1 = "由 scripts/gen-tokens.py 從 design-system/tokens/tokens.json 生成。"
_B2 = "不要手改這個檔——改 tokens.json 然後重跑生成器。make lint 會擋不一致。"
SWIFT_BANNER = f"// {_B1}\n// {_B2}"
CSS_BANNER   = f"/* {_B1}\n   {_B2} */"

def resolve(ref: str) -> str:
    scale, key = ref.split(".")
    return PRIM[scale][key]

def swift_color(spec) -> str:
    hexv = resolve(spec["ref"]).lstrip("#")
    base = f"Color(hex: 0x{hexv})"
    a = spec.get("alpha")
    return f"{base}.opacity({a})" if a is not None else base

def css_color(spec) -> str:
    r, g, b = (int(resolve(spec["ref"]).lstrip("#")[i:i+2], 16) for i in (0, 2, 4))
    a = spec.get("alpha")
    return f"rgb({r} {g} {b} / {a*100:g}%)" if a is not None else f"rgb({r} {g} {b})"

def num(v):
    return str(int(v)) if float(v) == int(v) else str(v)

# ─────────────────────────────── Swift ───────────────────────────────
def gen_swift() -> str:
    L = [SWIFT_BANNER, "//", "// Training La — 設計 token。所有 View 只讀這裡，不要在頁面裡寫死顏色或數字。",
         "// 分兩層：色階層（primitive）是固定色票；語意層（semantic）才是元件該用的東西。",
         "// 語意層之上還有一組『遷移中的舊名』，55 個檔在用，各階段榨取時逐步換掉。",
         "", "import SwiftUI", "", "// MARK: - Color", "",
         "extension Color {",
         "    /// 0xRRGGBB → Color（sRGB、不透明）。module 內部用。",
         "    init(hex: UInt32) {",
         "        self.init(.sRGB,",
         "                  red:   Double((hex >> 16) & 0xFF) / 255,",
         "                  green: Double((hex >>  8) & 0xFF) / 255,",
         "                  blue:  Double( hex        & 0xFF) / 255,",
         "                  opacity: 1)",
         "    }", "}", "",
         "public enum TLColor {"]

    # 色階層
    order = [("accent", "accent"), ("sage", "sage"), ("neutral", "neutral"), ("danger", "danger")]
    labels = {"accent": "主色 accent（赭紅）— 可操作的東西",
              "sage": "次色 sage（鼠尾草綠）— 分類標示（肌群）",
              "neutral": "中性 neutral（沙色階）— 資料容器",
              "danger": "警示 danger — 破壞性動作、確認鍵、輸入驗證錯誤"}
    L += ["", "    // ── 色階層 primitive ──────────────────────────────",
          "    // 固定色票，深色下不分支。元件不該直接用這一層，用下面的語意層。"]
    for scale, prefix in order:
        L += ["", f"    // {labels[scale]}"]
        for k in sorted(PRIM[scale], key=int):
            name = prefix if (k == BASE.get(scale)) else f"{prefix}{k}"
            L.append(f"    public static let {name:<12} = Color(hex: 0x{PRIM[scale][k].lstrip('#')})"
                     + ("  // base" if k == BASE.get(scale) else ""))
            if k == BASE.get(scale):
                L.append(f"    public static let {prefix + k:<12} = {prefix}")
    L += ["", "    // 沙色頁面底 / 表面，與最深的中性墨色（不屬於 100–900 色階）"]
    for k, v in PRIM["sand"].items():
        L.append(f"    public static let {'sand'+k.capitalize():<12} = Color(hex: 0x{v.lstrip('#')})")
    L.append(f"    public static let {'ink900':<12} = Color(hex: 0x{PRIM['ink']['900'].lstrip('#')})")

    # 語意層
    L += ["", "    // ── 語意層 semantic ───────────────────────────────",
          "    // 元件只准用這一層。名字描述角色，不描述外觀——所以深色接上時不用改名。",
          "    // C6a 會把這些改成隨 colorScheme 解析的 dynamic color；型別仍是 Color，呼叫端不動。"]
    w = max(len(n) for n in SEM)
    for name, spec in SEM.items():
        L.append(f"    public static let {name:<{w}} = {swift_color(spec['light'])}"
                 f"  // {spec['role']}")

    # 舊名
    LEG = D["legacyAliases"]
    L += ["", "    // ── 遷移中：舊名 ─────────────────────────────────",
          f"    // {LEG['note']}"]
    for old, new in LEG.items():
        if old == "note":
            continue
        L.append(f"    public static let {old:<8} = {new}")
    L += ["}", ""]

    # Space / Radius / Size
    L += ["// MARK: - Spacing / Radius / Size", "", "public enum TLSpace {"]
    notes = {"page": "頁面左右邊距", "section": "區塊之間", "rowInset": "列內左右 padding、分隔線左內縮"}
    w = max(len(k) for k in D["space"])
    for k, v in D["space"].items():
        L.append(f"    public static let {k+':':<{w+1}} CGFloat = {num(v):<4}" + (f"// {notes[k]}" if k in notes else ""))
    L += ["}", "", "public enum TLRadius {"]
    rn = {"container": "卡片／群組容器", "inner": "容器內的小方塊", "pill": "按鈕、輸入、標籤（實作用 .capsule）"}
    w = max(len(k) for k in D["radius"])
    for k, v in D["radius"].items():
        L.append(f"    public static let {k+':':<{w+1}} CGFloat = {num(v):<4}// {rn[k]}")
    L += ["}", "", "public enum TLSize {"]
    sn = {"row": "標準列高（設定列）", "rowWithSub": "有副標的列", "rowWithDetail": "有細節行的列（器材 pill ＋ 重量）",
          "rowHistory": "歷史列", "badge": "列左側圓章", "iconButton": "標題右側圓鈕（＝最小觸控）",
          "iconButtonSmall": "月曆標題列的 ‹ ›，觸控區另外補到 44"}
    w = max(len(k) for k in D["size"])
    for k, v in D["size"].items():
        L.append(f"    public static let {k+':':<{w+1}} CGFloat = {num(v):<4}" + (f"// {sn[k]}" if k in sn else ""))
    L += ["}", ""]

    # Typography
    T = D["type"]; sc = T["languageScale"]["en"]
    L += ["// MARK: - Typography", "//",
          "// 兩支字體分工：",
          f"//   數字與英文 → {T['families']['display']['name']}（打包進 bundle，runtime 註冊，見 FontRegistration.swift）",
          f"//   中文       → {T['families']['zh']['name']}（系統內建）；設計稿用 {T['families']['zh']['designProxy']} 代替",
          "//",
          f"// 語言補償：同一個角色，英文字級 = 中文字級 × {sc}",
          "// （中文撐滿字身框、英文只有 x-height，同 px 看起來小一號）",
          "//",
          "// Dynamic Type：每個角色的 relativeTo 目前都是 null，支援範圍等 C7a。",
          "// 位置留在 tokens.json 裡，屆時只改來源、不改呼叫端。", "",
          "public enum TLFont {",
          f"    /// 數字專用（{T['families']['display']['name']}）。第一次呼叫時確保字體已註冊。",
          "    public static func display(_ size: CGFloat) -> Font {",
          "        DesignSystemFonts.registerIfNeeded()",
          f"        return .custom(\"{T['families']['display']['name']}\", size: size)",
          "    }",
          f"    public static func zh(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {{",
          f"        .system(size: size, weight: weight)   // {T['families']['zh']['name']}",
          "    }",
          "    public static func en(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {",
          "        .system(size: size, weight: weight, design: .default)",
          "    }", "",
          f"    /// 英文模式的字級補償（同一角色 ×{sc}、四捨五入到整數）。",
          "    public static func scaled(_ size: CGFloat, isEnglish: Bool) -> CGFloat {",
          f"        isEnglish ? (size * {sc}).rounded() : size",
          "    }", "",
          f"    // 角色字級（中文值；英文乘 {sc}）"]
    w = max(len(k) for k in T["roles"])
    for k, r in T["roles"].items():
        note = r.get("note", "")
        L.append(f"    public static let {k+':':<{w+1}} CGFloat = {num(r['size']):<5}" + (f"// {note}" if note else ""))
    kick = T["roles"]["kicker"]
    L += ["",
          f"    /// kicker 的字距（{kick['trackingUnit']} → pt）。SwiftUI 的 tracking 吃點數，不是 {kick['trackingUnit']}。",
          f"    public static let kickerTracking: CGFloat = {num(kick['size'])} * {kick['tracking']}",
          "}", ""]

    # Shadow
    L += ["// MARK: - Shadow", "", "public enum TLShadow {", "    public struct Style: Sendable {",
          "        public let color: Color", "        public let radius: CGFloat", "        public let y: CGFloat",
          "    }"]
    for k, s in D["shadow"].items():
        L.append(f"    public static let {k} = Style(color: {swift_color(s['color'])}, "
                 f"radius: {num(s['radius'])}, y: {num(s['y'])})  // {s['use']}")
    L += ["}", "", "public extension View {", "    /// 套用 TLShadow。",
          "    func tlShadow(_ style: TLShadow.Style) -> some View {",
          "        shadow(color: style.color, radius: style.radius, x: 0, y: style.y)",
          "    }", "}", ""]
    return "\n".join(L)

# ──────────────────────────────── CSS ────────────────────────────────
def gen_css() -> str:
    T = D["type"]
    L = [CSS_BANNER, "",
         "@font-face {",
         f"  font-family: '{T['families']['display']['name']}';",
         f"  src: url('../fonts/{T['families']['display']['file']}') format('truetype');",
         "  font-display: swap;", "}", "", ":root {", "  /* ── 色階層 primitive ── */"]
    for scale in ("accent", "sage", "neutral", "danger"):
        for k in sorted(PRIM[scale], key=int):
            L.append(f"  --{scale}-{k}: {PRIM[scale][k]};")
    for k, v in PRIM["sand"].items():
        L.append(f"  --sand-{k}: {v};")
    L.append(f"  --ink-900: {PRIM['ink']['900']};")

    def kebab(s): return "".join("-" + c.lower() if c.isupper() else c for c in s)
    L.append("")
    L.append("  /* ── 語意層 semantic（淺色）── */")
    for name, spec in SEM.items():
        L.append(f"  --{kebab(name)}: {css_color(spec['light'])};  /* {spec['role']} */")

    L.append("")
    L.append("  /* ── 尺寸 ── */")
    for group in ("space", "radius", "size"):
        for k, v in D[group].items():
            L.append(f"  --{group}-{kebab(k)}: {num(v)}px;")
    L.append("")
    L.append("  /* ── 字級（中文值；英文 × %s）── */" % T["languageScale"]["en"])
    for k, r in T["roles"].items():
        L.append(f"  --font-{kebab(k)}: {num(r['size'])}px;")
    L.append(f"  --font-kicker-tracking: {T['roles']['kicker']['tracking']}em;")
    L.append(f"  --font-display: '{T['families']['display']['name']}', serif;")
    L.append(f"  --font-zh: '{T['families']['zh']['designProxy']}', '{T['families']['zh']['name']}', sans-serif;")
    L.append("")
    L.append("  /* ── 陰影 ── */")
    for k, s in D["shadow"].items():
        L.append(f"  --shadow-{k}: 0 {num(s['y'])}px {num(s['radius'])}px {css_color(s['color'])};  /* {s['use']} */")
    L.append("}")

    dark = ["", "/* 深色：目前是淺色的複製——位置先留好，實際色階等 C6a。",
            "   只有語意層有 theme 分支；色階層是固定色票，不在這裡覆寫。 */",
            "@media (prefers-color-scheme: dark) {", "  :root:not([data-theme=\"light\"]) {"]
    for name, spec in SEM.items():
        dark.append(f"    --{kebab(name)}: {css_color(spec['dark'])};")
    dark += ["  }", "}", "", ":root[data-theme=\"dark\"] {"]
    for name, spec in SEM.items():
        dark.append(f"  --{kebab(name)}: {css_color(spec['dark'])};")
    dark.append("}")
    return "\n".join(L + dark) + "\n"

if __name__ == "__main__":
    check = "--check" in sys.argv
    outs = [(SWIFT, gen_swift()), (CSS, gen_css())]
    bad = False
    for path, content in outs:
        if check:
            cur = path.read_text() if path.exists() else ""
            if cur != content:
                print(f"✘ {path.relative_to(ROOT)} 與 tokens.json 不一致——請跑 scripts/gen-tokens.py")
                bad = True
        else:
            path.write_text(content)
            print(f"✔ {path.relative_to(ROOT)}")
    sys.exit(1 if bad else 0)
