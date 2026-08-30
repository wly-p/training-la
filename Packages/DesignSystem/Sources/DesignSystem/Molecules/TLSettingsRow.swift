import SwiftUI

/// 模板 4：設定列。同容器規則（放進 `TLGroup`），列高 56、無圓章。
///
/// 文字吃 `Text`（呼叫端用 `localText` 建，見 TLPageHeader 說明）。
///
/// 右側型（用 trailing ViewBuilder 塞）：
///   - 值＋chevron：`trailing: { TLSettingsValue(localText("...")) }`、`showChevron: true`
///   - 分段控制：`trailing: { TLSegmentedControl(...) }`
/// 開關型請用 `TLSettingsToggleRow`（底層是 `Toggle`，保留 switch 無障礙語意）。
///
/// 破壞性列：`TLSettingsRow(localText("..."), role: .destructive) { … }`
/// → `danger-700` 文字＋垃圾桶圖示。
///
/// drill-in（值＋chevron 可點）建議傳 `accessibilityValue:`，讓 VoiceOver / UITest
/// 能以「標籤＋目前值」辨識（例：主題 = 深色）。
public struct TLSettingsRow<Trailing: View>: View {
    public enum Role { case normal, destructive }

    private let title: Text
    private let hint: Text?
    private let systemImage: String?
    private let role: Role
    private let showChevron: Bool
    private let accessibilityValue: Text?
    private let trailingGap: CGFloat
    private let onTap: (() -> Void)?
    private let trailing: Trailing

    public init(
        _ title: Text,
        hint: Text? = nil,
        systemImage: String? = nil,
        role: Role = .normal,
        showChevron: Bool = false,
        accessibilityValue: Text? = nil,
        trailingGap: CGFloat = TLSpace.gapS,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.hint = hint
        self.systemImage = systemImage
        self.role = role
        self.showChevron = showChevron
        self.accessibilityValue = accessibilityValue
        self.trailingGap = trailingGap
        self.onTap = onTap
        self.trailing = trailing()
    }

    private var titleColor: Color { role == .destructive ? TLColor.danger700 : TLColor.text }

    private var content: some View {
        // spacing 0 ＋ 各自的 padding：左側圖示與右側 chevron 的間距規格不同
        // （破壞性圖示 10、一般圖示 13、值→chevron 8、圖示預覽→chevron 10）。
        HStack(spacing: 0) {
            if role == .destructive {
                Image(systemName: systemImage ?? "trash")
                    .font(.system(size: TLFont.rowIcon, weight: .semibold))
                    .foregroundStyle(TLColor.danger700)
                    .padding(.trailing, TLSpace.sectionHeaderGap)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: TLFont.rowTitle, weight: .medium))
                    .foregroundStyle(TLColor.neutral600)
                    .padding(.trailing, TLSpace.gapM)
            }
            HStack(alignment: .firstTextBaseline, spacing: TLSpace.titleHintGap) {
                title
                    .font(TLFont.zh(TLFont.rowTitle, role == .destructive ? .semibold : .medium))
                    .foregroundStyle(titleColor)
                if let hint {
                    hint
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                }
            }
            Spacer(minLength: TLSpace.gapS)
            trailing
            if showChevron { TLChevron().padding(.leading, trailingGap) }
        }
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: TLSize.row)
        .contentShape(Rectangle())
    }

    public var body: some View {
        if let onTap {
            // 只覆寫 label/value（Button 本身已是單一 a11y 元素）；
            // 不要用 accessibilityElement(children:.ignore)——套在 Button 上會多出一個重複元素。
            Button(action: onTap) { content }
                .buttonStyle(TLRowPressStyle())
                .accessibilityLabel(title)
                .modifier(OptionalA11yValue(value: accessibilityValue))
        } else {
            content
        }
    }
}

/// 選擇性套 accessibilityValue（Text? → 有才套）。
private struct OptionalA11yValue: ViewModifier {
    let value: Text?
    func body(content: Content) -> some View {
        if let value {
            content.accessibilityValue(value)
        } else {
            content
        }
    }
}

public extension TLSettingsRow where Trailing == EmptyView {
    /// 只有標題／chevron 的最單純設定列。
    init(
        _ title: Text,
        hint: Text? = nil,
        systemImage: String? = nil,
        role: Role = .normal,
        showChevron: Bool = false,
        accessibilityValue: Text? = nil,
        trailingGap: CGFloat = TLSpace.gapS,
        onTap: (() -> Void)? = nil
    ) {
        self.init(title, hint: hint, systemImage: systemImage, role: role,
                  showChevron: showChevron, accessibilityValue: accessibilityValue,
                  trailingGap: trailingGap, onTap: onTap) { EmptyView() }
    }
}
