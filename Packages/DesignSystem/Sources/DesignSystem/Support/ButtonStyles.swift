import SwiftUI

// 模板 7：按鈕
// 規則：一個畫面最多一顆實心赭紅（主要操作），其餘降級為線框／文字。
// 互動：按下實心 → accent-700（破壞性 → danger-800）；按下線框／文字 → text @6%。無縮放動畫。
//
// 水平 padding 要寫在 `.frame(maxWidth: .infinity)` **之前**：全寬使用時它被撐開、看不出差別，
// 但呼叫端一旦加 `.fixedSize(horizontal: true)`（例如 EmptyState 的按鈕要內容寬），
// 沒有水平 padding 的膠囊就會直接貼死文字，看起來又小又擠。

/// 主要：capsule、accent 底、bg 字、15.5pt weight 700。
public struct TLPrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TLFont.zh(15.5, .bold))
            .foregroundStyle(TLColor.bg)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17.5)
            .background(configuration.isPressed ? TLColor.accent700 : TLColor.accent)
            .clipShape(Capsule())
            .contentShape(Capsule())
    }
}

/// 次要：capsule、1px text@18% 線框、透明底。按下 → text@6%。
public struct TLSecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TLFont.zh(15.5, .bold))
            .foregroundStyle(TLColor.text)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17.5)
            .background(configuration.isPressed ? TLColor.text.opacity(0.06) : Color.clear)
            .overlay(Capsule().strokeBorder(TLColor.text.opacity(0.18), lineWidth: 1))
            .clipShape(Capsule())
            .contentShape(Capsule())
    }
}

/// 文字動作：accent-700、14pt weight 600。
public struct TLTextButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TLFont.zh(14, .semibold))
            .foregroundStyle(TLColor.accent700)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

/// 破壞性（實心）：danger-600 底 / 按下 danger-800。用於確認對話框的確認鍵。
public struct TLDestructiveButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TLFont.zh(15.5, .bold))
            .foregroundStyle(TLColor.bg)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17.5)
            .background(configuration.isPressed ? TLColor.danger800 : TLColor.danger600)
            .clipShape(Capsule())
            .contentShape(Capsule())
    }
}

/// 破壞性（文字）：danger-700。
public struct TLDestructiveTextButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TLFont.zh(14, .semibold))
            .foregroundStyle(TLColor.danger700)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

// 用 `.buttonStyle(.tlPrimary)` 這種簡寫呼叫。
public extension ButtonStyle where Self == TLPrimaryButtonStyle {
    static var tlPrimary: TLPrimaryButtonStyle { .init() }
}
public extension ButtonStyle where Self == TLSecondaryButtonStyle {
    static var tlSecondary: TLSecondaryButtonStyle { .init() }
}
public extension ButtonStyle where Self == TLTextButtonStyle {
    static var tlText: TLTextButtonStyle { .init() }
}
public extension ButtonStyle where Self == TLDestructiveButtonStyle {
    static var tlDestructive: TLDestructiveButtonStyle { .init() }
}
public extension ButtonStyle where Self == TLDestructiveTextButtonStyle {
    static var tlDestructiveText: TLDestructiveTextButtonStyle { .init() }
}

/// 圓形圖示鈕：44×44 capsule。預設赭紅實心＋白色圖示（如頁首 `+`）。
public struct CircleIconButton: View {
    private let systemImage: String
    private let action: () -> Void
    private let filled: Bool

    /// - Parameter filled: true＝赭紅實心白圖示；false＝線框。
    public init(systemImage: String, filled: Bool = true, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.filled = filled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(filled ? TLColor.bg : TLColor.accent700)
                .frame(width: TLSize.iconButton, height: TLSize.iconButton)
                .background(filled ? TLColor.accent : Color.clear)
                .overlay(
                    Capsule().strokeBorder(TLColor.text.opacity(0.18), lineWidth: filled ? 0 : 1)
                )
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
