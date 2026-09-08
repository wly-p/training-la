import SwiftUI

/// 規格：`design-system/atoms/TLCircleIconButton/TLCircleIconButton.spec.md`
/// 圓形圖示鈕：預設 44×44 赭紅實心＋白色圖示（如頁首 `+`）。
///
/// **＝ `Button` ＋ `TLCircleIcon`。** 視覺全部在後者 —— 需要同樣的圓但不是按鈕的地方
/// （`Menu` 的 label）直接用 `TLCircleIcon`，不要重畫一份。
public struct TLCircleIconButton: View {
    public typealias Style = TLCircleIcon.Style

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
        iconSize: CGFloat = TLIcon.inIconButton,
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

    public var body: some View {
        Button(action: action) {
            TLCircleIcon(systemImage: systemImage, style: style,
                         size: size, iconSize: iconSize, iconWeight: iconWeight)
        }
        .buttonStyle(.plain)
    }
}
