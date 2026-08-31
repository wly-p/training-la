import SwiftUI

/// L1 原子。圓形圖示的**視覺**：固定直徑 ＋ 底色 ＋ 置中的 SF Symbol。
///
/// 規格：`design-system/atoms/TLCircleIcon/TLCircleIcon.spec.md`
///
/// **不可點** —— 點擊是 `TLCircleIconButton` 的事。
/// 分開的理由跟 `TLRowContent` 之於 `TLListRow` 一樣：這個視覺也會出現在
/// **不是按鈕的地方**（`Menu` 的 label），而按鈕自己擁有 `Button` 時那些地方就用不了它，
/// 只能手工重畫一份 —— 然後就漂了。
public struct TLCircleIcon: View {
    /// 三種材質。`neutral` 是月曆導航與訓練中的「更多」用的——
    /// 赭色留給狀態，導航與次要動作不跟狀態搶同一個顏色。
    public enum Style: Sendable {
        case accent     // 赭紅實心、白圖示
        case outline    // 線框、赭色圖示
        case neutral    // neutral-200 實心、深墨圖示
    }

    private let systemImage: String
    private let style: Style
    private let size: CGFloat
    private let iconSize: CGFloat
    private let iconWeight: Font.Weight

    public init(
        systemImage: String,
        style: Style = .accent,
        size: CGFloat = TLSize.iconButton,
        iconSize: CGFloat = TLIcon.inIconButton,
        iconWeight: Font.Weight = .semibold
    ) {
        self.systemImage = systemImage
        self.style = style
        self.size = size
        self.iconSize = iconSize
        self.iconWeight = iconWeight
    }

    private var foreground: Color {
        switch style {
        case .accent: TLColor.bg
        case .outline: TLColor.accent700
        case .neutral: TLColor.text
        }
    }

    private var background: Color {
        switch style {
        case .accent: TLColor.accent
        case .outline: Color.clear
        case .neutral: TLColor.neutral200
        }
    }

    public var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: iconWeight))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background)
            .overlay(
                Capsule().strokeBorder(TLColor.text.opacity(0.18), lineWidth: style == .outline ? 1 : 0)
            )
            .clipShape(Capsule())
            // 小尺寸（月曆的 34pt）本身低於最小觸控，外圈補到 44 才點得到；
            // contentShape 掛在補完的方框上，不是視覺的膠囊。
            .frame(minWidth: TLSize.minTap, minHeight: TLSize.minTap)
            .contentShape(Rectangle())
    }
}
