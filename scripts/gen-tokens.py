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
PREV = ROOT / "design-system/tokens/tokens.preview.html"
LEGP = ROOT / "design-system/tokens/_legacy-aliases.json"

D = json.loads(SRC.read_text())
PRIM, SEM = D["primitive"]["color"], D["semantic"]["color"]
BASE = D["primitive"]["scaleBase"]
LEG  = {k: v for k, v in json.loads(LEGP.read_text()).items() if k != "note"}

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

def swift_comment(text, indent="    "):
    """多行的 _note 要每一行都加 //，否則生成出來的 Swift 直接語法錯誤。
    （token 的說明值得寫成多行——壓成一行會沒人讀。）"""
    return "\n".join(f"{indent}// {ln}" if ln.strip() else f"{indent}//"
                     for ln in text.split("\n"))

def num(v):
    return str(int(v)) if float(v) == int(v) else str(v)

def _rgb(spec):
    h = resolve(spec["ref"]).lstrip("#")
    return [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]

def _lum(rgb):
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (f(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def contrast(fg_spec, bg_spec):
    """WCAG 對比度。文字類 token 的存在理由是可讀性，所以要把比值標出來——
    下次有人想把 accentOnSurface 改回 accent.500 時會先看到理由。"""
    a, b = _lum(_rgb(fg_spec)), _lum(_rgb(bg_spec))
    lo, hi = sorted((a, b))
    return (hi + 0.05) / (lo + 0.05)

# 文字類 token：它們的存在理由是「壓在某個底上還讀得動」，看色票方塊永遠判斷不出來。
TEXTISH = ("text", "accentOn", "dangerOn")

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
    L += ["", "    // ── 遷移中：舊名 ─────────────────────────────────",
          "    // 各階段榨取時逐步換成語意名。來源 tokens/_legacy-aliases.json（不進交付包）。"]
    for old, new in LEG.items():
        L.append(f"    public static let {old:<8} = {new}")
    L += ["}", ""]

    # Space / Radius / Size
    # 註解的來源是 tokens.json 的 _notes，不是這支腳本——生成器裡不放資料。
    NOTES = D.get("_notes", {})
    L += ["// MARK: - Spacing / Radius / Size", ""]
    for group, enum in (("space", "TLSpace"), ("radius", "TLRadius"), ("size", "TLSize")):
        L.append(f"public enum {enum} {{")
        notes = NOTES.get(group, {})
        w = max(len(k) for k in D[group])
        for k, v in D[group].items():
            note = notes.get(k, "")
            line = f"    public static let {k+':':<{w+1}} CGFloat = {num(v):<4}" + (f"// {note}" if note else "")
            L.append(line.rstrip())
        L += ["}", ""]

    I = D["icon"]
    L += ["public enum TLIcon {", swift_comment(I["_note"])]
    # strokeWeb 只作用於 web／設計側（Lucide 的 stroke），Swift 這邊用不到，不輸出。
    for k in [k for k, v in I.items()
              if not k.startswith("_") and isinstance(v, (int, float)) and k != "strokeWeb"]:
        L.append(f"    public static let {k}: CGFloat = {num(I[k])}")
    L += [f"    public static let weight: Font.Weight = .{I['weight']}", "}", ""]

    M = D["motion"]
    L += ["public enum TLMotion {", swift_comment(M["_note"]),
          f"    public static let fast: Double = {M['fast']}",
          f"    public static let base: Double = {M['base']}",
          f"    public static var quick: Animation {{ .{M['curve']}(duration: fast) }}",
          f"    public static var standard: Animation {{ .{M['curve']}(duration: base) }}",
          "}", ""]

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
        bits = [f"{r['family']} 家族"] + ([r["note"]] if r.get("note") else [])
        L.append(f"    public static let {k+':':<{w+1}} CGFloat = {num(r['size']):<5}// {'；'.join(bits)}")
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
         "  font-display: swap;", "}", "",
         f"/* {T['families']['zh']['_note']} */",
         "@font-face {",
         f"  font-family: '{T['families']['zh']['designProxy']}';",
         f"  src: url('../fonts/{T['families']['zh']['previewFont']}') format('woff2');",
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
        notes = D.get("_notes", {}).get(group, {})
        for k, v in D[group].items():
            note = notes.get(k, "")
            L.append(f"  --{group}-{kebab(k)}: {num(v)}px;" + (f"  /* {note} */" if note else ""))
    L.append("")
    L.append("  /* ── 字級（中文值；英文 × %s）── */" % T["languageScale"]["en"])
    for k, r in T["roles"].items():
        L.append(f"  --font-{kebab(k)}: {num(r['size'])}px;")
    L.append(f"  --font-kicker-tracking: {T['roles']['kicker']['tracking']}em;")
    L.append("")
    L.append("  /* 家族。每個角色歸屬哪一支見下面的 --font-<role>-family。 */")
    L.append(f"  --font-display: '{T['families']['display']['name']}', serif;")
    L.append(f"  --font-zh: '{T['families']['zh']['designProxy']}', '{T['families']['zh']['name']}', sans-serif;")
    L.append("  --font-en: system-ui, -apple-system, sans-serif;")
    for k, r in T["roles"].items():
        L.append(f"  --font-{kebab(k)}-family: var(--font-{r['family']});")
    L.append("")
    L.append(f"  /* 圖示。{D['icon']['_note']} */")
    for k in [k for k, v in D["icon"].items() if not k.startswith("_") and isinstance(v, (int, float))]:
        L.append(f"  --icon-{k}: {num(D['icon'][k])}px;")
    L.append(f"  --icon-stroke: {D['icon']['strokeWeb']};")
    L.append("")
    L.append("  /* 動效 */")
    L.append(f"  --motion-fast: {D['motion']['fast']}s;")
    L.append(f"  --motion-base: {D['motion']['base']}s;")
    L.append(f"  --motion-curve: cubic-bezier(0, 0, 0.58, 1);  /* {D['motion']['_curveNote']} */")
    L.append("")
    L.append("  /* ── 陰影 ── */")
    for k, s in D["shadow"].items():
        L.append(f"  --shadow-{k}: 0 {num(s['y'])}px {num(s['radius'])}px {css_color(s['color'])};  /* {s['use']} */")
    L.append("}")

    dark = ["", "/* 深色：目前是淺色的複製——位置先留好，實際色階等 C6a。",
            "   只有語意層有 theme 分支；色階層是固定色票，不在這裡覆寫。",
            "",
            "   選擇器刻意用 [data-theme=\"dark\"] 而不是 :root[data-theme=\"dark\"]：",
            "   preview 要能把兩個主題並排在同一頁（各自掛在子元素上對照），",
            "   綁死 :root 的話只有整頁切換才生效，並排永遠是同一個主題。 */",
            "@media (prefers-color-scheme: dark) {", "  :root:not([data-theme=\"light\"]) {"]
    for name, spec in SEM.items():
        dark.append(f"    --{kebab(name)}: {css_color(spec['dark'])};")
    dark += ["  }", "}", "", "[data-theme=\"dark\"] {"]
    for name, spec in SEM.items():
        dark.append(f"  --{kebab(name)}: {css_color(spec['dark'])};")
    dark += ["}", "", "[data-theme=\"light\"] {"]
    for name, spec in SEM.items():
        dark.append(f"  --{kebab(name)}: {css_color(spec['light'])};")
    dark.append("}")
    return "\n".join(L + dark) + "\n"

# ─────────────────────── tokens 視覺參考頁 ───────────────────────
def gen_tokens_preview() -> str:
    T = D["type"]
    def kebab(s): return "".join("-" + c.lower() if c.isupper() else c for c in s)
    L = ['<!doctype html>', '<meta charset="utf-8">', '<title>Token 參考</title>',
         '<link rel="stylesheet" href="tokens.css">',
         '<link rel="stylesheet" href="../preview.css">',
         '<style>',
         '  .swatches { display: flex; flex-wrap: wrap; gap: 2px; }',
         '  .sw { width: 76px; }',
         '  .chip { height: 46px; border-radius: 6px; border: 1px solid var(--border-subtle); }',

         '  .cap { font-size: var(--font-kicker); color: var(--text-tertiary); margin-top: 4px; }',
         '  .bar { background: var(--action-primary); height: 12px; border-radius: 3px; }',
         '  .box { background: var(--surface-track); width: 92px; height: 60px;',
         '         display: inline-block; margin-right: var(--space-gap-m); }',
         '</style>',
         '<h1>Token 參考</h1>',
         '<p class="note">全部由 <code>tokens.json</code> 生成。要改值改來源，不要改這頁。<br>'
         '色階層是固定色票，元件不該直接用；語意層才是元件該用的東西。</p>']

    L.append('<div class="kicker">色階層 primitive</div>')
    for scale in ("accent", "sage", "neutral", "danger"):
        L.append(f'<div class="cap">{scale}</div><div class="swatches">')
        for k in sorted(PRIM[scale], key=int):
            L.append(f'  <div class="sw"><div class="chip" style="background: var(--{scale}-{k})"></div>'
                     f'<div class="cap">{k}</div></div>')
        L.append('</div>')
    L.append('<div class="cap">sand / ink</div><div class="swatches">')
    for k in PRIM["sand"]:
        L.append(f'  <div class="sw"><div class="chip" style="background: var(--sand-{k})"></div>'
                 f'<div class="cap">sand.{k}</div></div>')
    L.append('  <div class="sw"><div class="chip" style="background: var(--ink-900)"></div>'
             '<div class="cap">ink.900</div></div></div>')

    text_toks = {k: v for k, v in SEM.items() if k.startswith(TEXTISH)}
    fill_toks = {k: v for k, v in SEM.items() if not k.startswith(TEXTISH)}

    L.append('<div class="kicker">語意層 · 文字類 — 壓在 surface-raised 上的實際樣子</div>')
    L.append('<p class="note">這幾個 token 的存在理由是<b>可讀性</b>，不是顏色本身。'
             'accent-on-surface 是 accent.700 而不是 500，'
             '整個原因就是 500 壓在容器底上讀不動。對比度是對 <code>surface-raised</code> 算的；'
             'WCAG 正文要 4.5:1，大字與圖示 3:1。</p>')
    L.append('<div class="group" style="background: var(--surface-raised)">')
    for name, spec in text_toks.items():
        ratio = contrast(spec["light"], SEM["surfaceRaised"]["light"])
        flag = "" if ratio >= 4.5 else ("　⚠ 僅足夠大字／圖示" if ratio >= 3 else "　⚠ 對比不足")
        L.append(f'  <div class="row"><span class="label" '
                 f'style="color: var(--{kebab(name)})">主文字範例 訓練 Training 12.5</span>'
                 f'<span class="cap"><code>{kebab(name)}</code> → {spec["light"]["ref"]}'
                 f'　{ratio:.1f}:1{flag}</span></div>')
    L.append('</div>')

    L.append('<div class="kicker">語意層 · 底色與線條</div><div class="group">')
    for name, spec in fill_toks.items():
        # 半透明的 token（borderSubtle 是 8%）疊在同色底上幾乎看不見。
        # 用分層背景把它合成在 neutral-400 上，才分辨得出實際的濃度。
        L.append(f'  <div class="row"><span class="chip" style="width:34px;height:34px;'
                 f'background: linear-gradient(var(--{kebab(name)}), var(--{kebab(name)})),'
                 f' var(--neutral-400)"></span>'
                 f'<span class="label"><code>{kebab(name)}</code> — {spec["role"]}</span>'
                 f'<span class="cap">→ {spec["light"]["ref"]}'
                 + (f' @ {spec["light"]["alpha"]:g}' if "alpha" in spec["light"] else "")
                 + '</span></div>')
    L.append('</div>')

    L.append('<div class="kicker">字級角色（中文值；英文 × %s）</div><div class="group">' % T["languageScale"]["en"])
    for k, r in T["roles"].items():
        L.append(f'  <div class="row" style="height:auto;padding-top:var(--space-gap-m);'
                 f'padding-bottom:var(--space-gap-m)">'
                 f'<span class="label" style="font-size: var(--font-{kebab(k)});'
                 f'font-family: var(--font-{kebab(k)}-family)">'
                 + ("12.5 kg × 8" if r["family"] == "display" else "訓練 Training")
                 + f'</span><span class="cap"><code>{kebab(k)}</code> {num(r["size"])} · {r["family"]}</span></div>')
    L.append('</div>')

    L.append('<div class="kicker">間距</div><div class="group">')
    for k, v in D["space"].items():
        L.append(f'  <div class="row"><span class="label"><code>{kebab(k)}</code></span>'
                 f'<span class="bar" style="width: var(--space-{kebab(k)})"></span>'
                 f'<span class="cap">{num(v)}</span></div>')
    L.append('</div>')

    L.append('<div class="kicker">圓角</div><p>')
    for k, v in D["radius"].items():
        L.append(f'  <span class="box" style="border-radius: var(--radius-{k})"></span>')
    L.append('</p><p class="cap">' + " · ".join(f"{k} {num(v)}" for k, v in D["radius"].items()) + '</p>')

    L.append('<div class="kicker">陰影</div><p>')
    for k in D["shadow"]:
        L.append(f'  <span class="box" style="background: var(--surface-raised);'
                 f'border-radius: var(--radius-inner); box-shadow: var(--shadow-{k})"></span>')
    L.append('</p><p class="cap">' + " · ".join(f"{k}（{s['use']}）" for k, s in D["shadow"].items()) + '</p>')

    L.append('<div class="kicker">圖示尺寸與動效</div><p class="note">'
             + " · ".join(f"<code>icon.{k}</code> {num(v)}"
                           for k, v in D["icon"].items()
                           if not k.startswith("_") and isinstance(v, (int, float)))
             + f" · stroke {D['icon']['strokeWeb']}<br>"
             + f'<code>motion.fast</code> {D["motion"]["fast"]}s · '
             + f'<code>motion.base</code> {D["motion"]["base"]}s · {D["motion"]["curve"]}</p>')
    return "\n".join(L) + "\n"

if __name__ == "__main__":
    check = "--check" in sys.argv
    outs = [(SWIFT, gen_swift()), (CSS, gen_css()), (PREV, gen_tokens_preview())]
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
