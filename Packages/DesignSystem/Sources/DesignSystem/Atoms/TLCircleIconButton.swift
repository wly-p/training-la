import SwiftUI

/// 規格：`design-system/atoms/TLCircleIconButton/TLCircleIconButton.spec.md`
/// 圓形圖示鈕：預設 44×44 赭紅實心＋白色圖示（如頁首 `+`）。
public struct TLCircleIconButton: View {
    /// 三種材質。`neutral` 是月曆標題列那組導航（`‹ ›`）用的——與「今天」膠囊同材質，
    /// 赭色留給日期格子的「已排定」，導航鍵不跟狀態搶同一個顏色。
    public enum Style: Sendable {
        case accent     // 赭紅實心、白圖示
        case outline    // 線框、赭色圖示
        case neutral    // neutral-200 實心、深墨圖示
    }

    private let systemImage: String
    private let action: () -> Void
    private let style: Style
    private let size: CGFloat
    private let iconSize: CGFloat
    private let iconWeight: Font.Weight

    public init(
        systemImage: String,
        style: Style = .accent,
        size: CGFloat = TLSize.iconButton,
        iconSize: CGFloat = TLIcon.button,
        iconWeight: Font.Weight = .semibold,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.style = style
        self.size = size
        self.iconSize = iconSize
        self.iconWeight = iconWeight
        self.action = action
    }

    /// 舊呼叫端相容：`filled: true/false` ＝ `.accent` / `.outline`。
    public init(systemImage: String, filled: Bool, action: @escaping () -> Void) {
        self.init(systemImage: systemImage, style: filled ? .accent : .outline, action: action)
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
        Button(action: action) {
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
        .buttonStyle(.plain)
    }
}
