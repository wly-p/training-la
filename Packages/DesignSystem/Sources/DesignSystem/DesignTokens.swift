// DesignTokens.swift
// Training La — 設計 token 單一真實來源。
// 所有 View 只讀這裡，不要在頁面裡寫死顏色或數字。
// 來源：Organic design system + 本專案補的 danger 色階。
//
// 對照 handoff 版本：值完全相同，只加上 `public`（跨 module 使用）。

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
    // 語意角色
    public static let bg       = Color(hex: 0xF5EAD8)   // 頁面底色（奶油）
    public static let surface  = Color(hex: 0xEBDDC5)   // 表面（沙）
    public static let text     = Color(hex: 0x201E1D)   // 主文字
    public static let divider  = Color(hex: 0x201E1D).opacity(0.08) // 列間分隔線

    // 主色 accent（赭紅）— 可操作的東西
    public static let accent100 = Color(hex: 0xFFF2EB)
    public static let accent200 = Color(hex: 0xFFE1D0)
    public static let accent300 = Color(hex: 0xFFC6A5)
    public static let accent400 = Color(hex: 0xF6A06B)
    public static let accent    = Color(hex: 0xC67139)  // base
    public static let accent600 = Color(hex: 0xB2622D)
    public static let accent700 = Color(hex: 0x8C491A)  // 淺底上的可讀文字
    public static let accent800 = Color(hex: 0x643312)
    public static let accent900 = Color(hex: 0x402310)

    // 次色 accent2（鼠尾草綠）— 分類標示（肌群）
    public static let sage100 = Color(hex: 0xF0FAE1)
    public static let sage200 = Color(hex: 0xE1EECC)
    public static let sage300 = Color(hex: 0xCCDBB2)
    public static let sage400 = Color(hex: 0xAEBF92)
    public static let sage    = Color(hex: 0x7A8A5E)
    public static let sage600 = Color(hex: 0x728157)
    public static let sage700 = Color(hex: 0x56633F)
    public static let sage800 = Color(hex: 0x3D472B)
    public static let sage900 = Color(hex: 0x272E1B)

    // 中性 neutral（沙色階）— 資料容器
    public static let neutral100 = Color(hex: 0xF9F4ED)  // 卡片／群組容器底
    public static let neutral200 = Color(hex: 0xEEE7DB)  // 分段控制軌道
    public static let neutral300 = Color(hex: 0xDCD3C4)  // 輸入色帶（訓練頁）
    public static let neutral400 = Color(hex: 0xC0B6A5)
    public static let neutral500 = Color(hex: 0xA19786)  // 三級文字／icon
    public static let neutral600 = Color(hex: 0x82796A)  // 二級文字
    public static let neutral700 = Color(hex: 0x645C50)
    public static let neutral800 = Color(hex: 0x474238)
    public static let neutral900 = Color(hex: 0x2E2B25)  // 大數字

    // 警示 danger — 本專案新增，Organic 原本沒有
    // 只用於：破壞性動作、確認對話框的確認鍵、輸入驗證錯誤
    //
    // handoff-20 D 節：原本是生紅（色相約 4°），與整頁赭色系（accent 約 24°）不同調。
    // 淺階往赭色靠、色相收在 9～17° 之間，看起來才像同一套色票裡的「警示版本」。
    public static let danger100 = Color(hex: 0xFAEDE8)
    public static let danger200 = Color(hex: 0xF3DDD6)  // 外框破壞性按鈕的按下底色
    public static let danger300 = Color(hex: 0xD9A89B)
    public static let danger400 = Color(hex: 0xB8776A)  // 外框破壞性按鈕的邊
    public static let danger    = Color(hex: 0xD96552)
    public static let danger600 = Color(hex: 0xB74736)  // 實心底（見 TLDestructiveButtonStyle：目前無使用者）
    public static let danger700 = Color(hex: 0x7E3123)  // 淺底上的文字、圖示、外框按鈕的字
    public static let danger800 = Color(hex: 0x661F14)
    public static let danger900 = Color(hex: 0x40140D)
}

// MARK: - Spacing / Radius / Size

public enum TLSpace {
    public static let page: CGFloat      = 26   // 頁面左右邊距
    public static let section: CGFloat   = 26   // 區塊之間
    public static let rowInset: CGFloat  = 18   // 列內左右 padding、分隔線左內縮
    public static let gapS: CGFloat      = 8
    public static let gapM: CGFloat      = 13
    public static let gapL: CGFloat      = 20
}

public enum TLRadius {
    public static let container: CGFloat = 28   // 卡片／群組容器
    public static let inner: CGFloat     = 20   // 容器內的小方塊
    public static let pill: CGFloat      = 999  // 按鈕、輸入、標籤（實作用 .capsule）
}

public enum TLSize {
    public static let row: CGFloat        = 56  // 標準列高（設定列）
    public static let rowWithSub: CGFloat = 62  // 有副標的列
    public static let rowWithDetail: CGFloat = 68  // 有細節行的列（器材 pill ＋ 重量，見 19a）
    public static let rowHistory: CGFloat = 66  // 歷史列
    public static let badge: CGFloat      = 36  // 列左側圓章
    public static let iconButton: CGFloat = 44  // 標題右側圓鈕（＝最小觸控）
    public static let iconButtonSmall: CGFloat = 34  // 月曆標題列的 ‹ ›，觸控區另外補到 44
    public static let minTap: CGFloat     = 44
    public static let switchW: CGFloat    = 46
    public static let switchH: CGFloat    = 28
}

// MARK: - Typography
//
// 兩支字體分工：
//   數字與英文 → Caprasimo（打包進 bundle，runtime 註冊，見 FontRegistration.swift）
//   中文       → PingFang TC（系統內建）；設計稿用 Noto Sans TC 代替
//
// 語言補償：同一個角色，英文字級 = 中文字級 × 1.08
// （中文撐滿字身框、英文只有 x-height，同 px 看起來小一號）

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
    public static let pageTitle: CGFloat   = 34   // 頁面主標，允許兩行
    public static let cardTitle: CGFloat   = 21
    public static let rowTitle: CGFloat    = 15
    public static let rowSub: CGFloat      = 11.5
    public static let kicker: CGFloat      = 10.5 // 大寫、字距 0.16em
    public static let bigNumber: CGFloat   = 66   // 訓練頁重量／次數

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
    public static let sm = Style(color: Color(hex: 0x2E2B25).opacity(0.14), radius: 2, y: 1)   // 卡片
    public static let md = Style(color: Color(hex: 0x2E2B25).opacity(0.16), radius: 10, y: 3)  // 分段控制選中膠囊
    public static let lg = Style(color: Color(hex: 0x2E2B25).opacity(0.22), radius: 32, y: 12) // 對話框
}

public extension View {
    /// 套用 TLShadow。
    func tlShadow(_ style: TLShadow.Style) -> some View {
        shadow(color: style.color, radius: style.radius, x: 0, y: style.y)
    }
}
