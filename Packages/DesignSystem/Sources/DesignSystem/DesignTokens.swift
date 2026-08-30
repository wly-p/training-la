// 由 scripts/gen-tokens.py 從 design-system/tokens/tokens.json 生成。
// 不要手改這個檔——改 tokens.json 然後重跑生成器。make lint 會擋不一致。
//
// Training La — 設計 token。所有 View 只讀這裡，不要在頁面裡寫死顏色或數字。
// 分兩層：色階層（primitive）是固定色票；語意層（semantic）才是元件該用的東西。
// 語意層之上還有一組『遷移中的舊名』，55 個檔在用，各階段榨取時逐步換掉。

import SwiftUI

// MARK: - Color

extension Color {
    /// 0xRRGGBB → Color（sRGB、不透明）。module 內部用。
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >>  8) & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255,
                  opacity: 1)
    }
}

public enum TLColor {

    // ── 色階層 primitive ──────────────────────────────
    // 固定色票，深色下不分支。元件不該直接用這一層，用下面的語意層。

    // 主色 accent（赭紅）— 可操作的東西
    public static let accent100    = Color(hex: 0xFFF2EB)
    public static let accent200    = Color(hex: 0xFFE1D0)
    public static let accent300    = Color(hex: 0xFFC6A5)
    public static let accent400    = Color(hex: 0xF6A06B)
    public static let accent       = Color(hex: 0xC67139)  // base
    public static let accent500    = accent
    public static let accent600    = Color(hex: 0xB2622D)
    public static let accent700    = Color(hex: 0x8C491A)
    public static let accent800    = Color(hex: 0x643312)
    public static let accent900    = Color(hex: 0x402310)

    // 次色 sage（鼠尾草綠）— 分類標示（肌群）
    public static let sage100      = Color(hex: 0xF0FAE1)
    public static let sage200      = Color(hex: 0xE1EECC)
    public static let sage300      = Color(hex: 0xCCDBB2)
    public static let sage400      = Color(hex: 0xAEBF92)
    public static let sage         = Color(hex: 0x7A8A5E)  // base
    public static let sage500      = sage
    public static let sage600      = Color(hex: 0x728157)
    public static let sage700      = Color(hex: 0x56633F)
    public static let sage800      = Color(hex: 0x3D472B)
    public static let sage900      = Color(hex: 0x272E1B)

    // 中性 neutral（沙色階）— 資料容器
    public static let neutral100   = Color(hex: 0xF9F4ED)
    public static let neutral200   = Color(hex: 0xEEE7DB)
    public static let neutral300   = Color(hex: 0xDCD3C4)
    public static let neutral400   = Color(hex: 0xC0B6A5)
    public static let neutral500   = Color(hex: 0xA19786)
    public static let neutral600   = Color(hex: 0x82796A)
    public static let neutral700   = Color(hex: 0x645C50)
    public static let neutral800   = Color(hex: 0x474238)
    public static let neutral900   = Color(hex: 0x2E2B25)

    // 警示 danger — 破壞性動作、確認鍵、輸入驗證錯誤
    public static let danger100    = Color(hex: 0xFAEDE8)
    public static let danger200    = Color(hex: 0xF3DDD6)
    public static let danger300    = Color(hex: 0xD9A89B)
    public static let danger400    = Color(hex: 0xB8776A)
    public static let danger       = Color(hex: 0xD96552)  // base
    public static let danger500    = danger
    public static let danger600    = Color(hex: 0xB74736)
    public static let danger700    = Color(hex: 0x7E3123)
    public static let danger800    = Color(hex: 0x661F14)
    public static let danger900    = Color(hex: 0x40140D)

    // 沙色頁面底 / 表面，與最深的中性墨色（不屬於 100–900 色階）
    public static let sandBase     = Color(hex: 0xF5EAD8)
    public static let sandRaised   = Color(hex: 0xEBDDC5)
    public static let ink900       = Color(hex: 0x201E1D)

    // ── 語意層 semantic ───────────────────────────────
    // 元件只准用這一層。名字描述角色，不描述外觀——所以深色接上時不用改名。
    // C6a 會把這些改成隨 colorScheme 解析的 dynamic color；型別仍是 Color，呼叫端不動。
    public static let surfaceBase     = Color(hex: 0xF5EAD8)  // 頁面底色
    public static let surfaceRaised   = Color(hex: 0xF9F4ED)  // 卡片／群組容器底
    public static let surfaceTrack    = Color(hex: 0xEEE7DB)  // 分段控制軌道
    public static let surfaceInput    = Color(hex: 0xDCD3C4)  // 輸入色帶（訓練頁）
    public static let textPrimary     = Color(hex: 0x201E1D)  // 主文字
    public static let textSecondary   = Color(hex: 0x82796A)  // 二級文字
    public static let textTertiary    = Color(hex: 0xA19786)  // 三級文字／icon
    public static let textNumeric     = Color(hex: 0x2E2B25)  // 大數字
    public static let borderSubtle    = Color(hex: 0x201E1D).opacity(0.08)  // 列間分隔線
    public static let actionPrimary   = Color(hex: 0xC67139)  // 可操作的東西（赭紅）
    public static let actionPressed   = Color(hex: 0xB2622D)  // 實心按鈕按下態
    public static let categoryTag     = Color(hex: 0x7A8A5E)  // 分類標示（肌群）
    public static let dangerSolid     = Color(hex: 0xB74736)  // 破壞性實心底
    public static let accentOnSurface = Color(hex: 0x8C491A)  // 在容器底上的可讀 accent 文字
    public static let dangerOnSurface = Color(hex: 0x7E3123)  // 在容器底上的破壞性文字／外框

    // ── 遷移中：舊名 ─────────────────────────────────
    // 各階段榨取時逐步換成語意名。來源 tokens/_legacy-aliases.json（不進交付包）。
    public static let bg       = surfaceBase
    public static let text     = textPrimary
    public static let divider  = borderSubtle
}

// MARK: - Spacing / Radius / Size

public enum TLSpace {
    public static let page:     CGFloat = 26  // 頁面左右邊距
    public static let section:  CGFloat = 26  // 區塊之間
    public static let rowInset: CGFloat = 18  // 列內左右 padding、分隔線左內縮
    public static let gapS:     CGFloat = 8   
    public static let gapM:     CGFloat = 13  
    public static let gapL:     CGFloat = 20  
}

public enum TLRadius {
    public static let container: CGFloat = 28  // 卡片／群組容器
    public static let inner:     CGFloat = 20  // 容器內的小方塊
    public static let pill:      CGFloat = 999 // 按鈕、輸入、標籤（實作用 .capsule）
}

public enum TLSize {
    public static let row:             CGFloat = 56  // 標準列高（設定列）
    public static let rowWithSub:      CGFloat = 62  // 有副標的列
    public static let rowWithDetail:   CGFloat = 68  // 有細節行的列（器材 pill ＋ 重量）
    public static let rowHistory:      CGFloat = 66  // 歷史列
    public static let badge:           CGFloat = 36  // 列左側圓章
    public static let iconButton:      CGFloat = 44  // 標題右側圓鈕（＝最小觸控）
    public static let iconButtonSmall: CGFloat = 34  // 月曆標題列的 ‹ ›，觸控區另外補到 44
    public static let minTap:          CGFloat = 44  
    public static let switchW:         CGFloat = 46  
    public static let switchH:         CGFloat = 28  
}

public enum TLIcon {
    // SF Symbol 的視覺尺寸。weight 只作用於 SF Symbol（實作側）；web／設計側用 Lucide 形狀配 strokeWeb。
    public static let s: CGFloat = 13
    public static let m: CGFloat = 16
    public static let l: CGFloat = 20
    public static let weight: Font.Weight = .semibold
}

public enum TLMotion {
    // 來自程式碼現況：easeOut 0.2（4 處）、0.18（1 處）、0.15（1 處）。0.18 是落單值，之後應收斂到 fast 或 base，收斂前不要新增第四個值。
    public static let fast: Double = 0.15
    public static let base: Double = 0.2
    public static var quick: Animation { .easeOut(duration: fast) }
    public static var standard: Animation { .easeOut(duration: base) }
}

// MARK: - Typography
//
// 兩支字體分工：
//   數字與英文 → Caprasimo（打包進 bundle，runtime 註冊，見 FontRegistration.swift）
//   中文       → PingFang TC（系統內建）；設計稿用 Noto Sans TC 代替
//
// 語言補償：同一個角色，英文字級 = 中文字級 × 1.08
// （中文撐滿字身框、英文只有 x-height，同 px 看起來小一號）
//
// Dynamic Type：每個角色的 relativeTo 目前都是 null，支援範圍等 C7a。
// 位置留在 tokens.json 裡，屆時只改來源、不改呼叫端。

public enum TLFont {
    /// 數字專用（Caprasimo）。第一次呼叫時確保字體已註冊。
    public static func display(_ size: CGFloat) -> Font {
        DesignSystemFonts.registerIfNeeded()
        return .custom("Caprasimo", size: size)
    }
    public static func zh(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight)   // PingFang TC
    }
    public static func en(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// 英文模式的字級補償（同一角色 ×1.08、四捨五入到整數）。
    public static func scaled(_ size: CGFloat, isEnglish: Bool) -> CGFloat {
        isEnglish ? (size * 1.08).rounded() : size
    }

    // 角色字級（中文值；英文乘 1.08）
    public static let pageTitle: CGFloat = 34   // zh 家族；頁面主標，允許兩行
    public static let cardTitle: CGFloat = 21   // zh 家族
    public static let rowTitle:  CGFloat = 15   // zh 家族
    public static let rowSub:    CGFloat = 11.5 // zh 家族
    public static let kicker:    CGFloat = 10.5 // zh 家族；大寫
    public static let bigNumber: CGFloat = 66   // display 家族；訓練頁重量／次數

    /// kicker 的字距（em → pt）。SwiftUI 的 tracking 吃點數，不是 em。
    public static let kickerTracking: CGFloat = 10.5 * 0.16
}

// MARK: - Shadow

public enum TLShadow {
    public struct Style: Sendable {
        public let color: Color
        public let radius: CGFloat
        public let y: CGFloat
    }
    public static let sm = Style(color: Color(hex: 0x2E2B25).opacity(0.14), radius: 2, y: 1)  // 卡片
    public static let md = Style(color: Color(hex: 0x2E2B25).opacity(0.16), radius: 10, y: 3)  // 分段控制選中膠囊
    public static let lg = Style(color: Color(hex: 0x2E2B25).opacity(0.22), radius: 32, y: 12)  // 對話框
}

public extension View {
    /// 套用 TLShadow。
    func tlShadow(_ style: TLShadow.Style) -> some View {
        shadow(color: style.color, radius: style.radius, x: 0, y: style.y)
    }
}
