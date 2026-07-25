import SwiftUI

/// 模板 4：設定列。同容器規則（放進 `TLGroup`），列高 56、無圓章。
///
/// 文字吃 `Text`（呼叫端用 `localText` 建，見 PageHeader 說明）。
///
/// 右側型（用 trailing ViewBuilder 塞）：
///   - 值＋chevron：`trailing: { SettingsValue(localText("...")) }`、`showChevron: true`
///   - 分段控制：`trailing: { TLSegmentedControl(...) }`
/// 開關型請用 `SettingsToggleRow`（底層是 `Toggle`，保留 switch 無障礙語意）。
///
/// 破壞性列：`SettingsRow(localText("..."), role: .destructive) { … }`
/// → `danger-700` 文字＋垃圾桶圖示。
///
/// drill-in（值＋chevron 可點）建議傳 `accessibilityValue:`，讓 VoiceOver / UITest
/// 能以「標籤＋目前值」辨識（例：主題 = 深色）。
public struct SettingsRow<Trailing: View>: View {
    public enum Role { case normal, destructive }

    private let title: Text
    private let hint: Text?
    private let systemImage: String?
    private let role: Role
    private let showChevron: Bool
    private let accessibilityValue: Text?
    private let onTap: (() -> Void)?
    private let trailing: Trailing

    public init(
        _ title: Text,
        hint: Text? = nil,
        systemImage: String? = nil,
        role: Role = .normal,
        showChevron: Bool = false,
        accessibilityValue: Text? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.hint = hint
        self.systemImage = systemImage
        self.role = role
        self.showChevron = showChevron
        self.accessibilityValue = accessibilityValue
        self.onTap = onTap
        self.trailing = trailing()
    }

    private var titleColor: Color { role == .destructive ? TLColor.danger700 : TLColor.text }

    private var content: some View {
        HStack(spacing: TLSpace.gapM) {
            if role == .destructive {
                Image(systemName: systemImage ?? "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TLColor.danger700)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(TLColor.neutral600)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                title
                    .font(TLFont.zh(TLFont.rowTitle))
                    .foregroundStyle(titleColor)
                if let hint {
                    hint
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                }
            }
            Spacer(minLength: TLSpace.gapS)
            trailing
            if showChevron { Chevron() }
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
                .buttonStyle(RowPressStyle())
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

public extension SettingsRow where Trailing == EmptyView {
    /// 只有標題／chevron 的最單純設定列。
    init(
        _ title: Text,
        hint: Text? = nil,
        systemImage: String? = nil,
        role: Role = .normal,
        showChevron: Bool = false,
        accessibilityValue: Text? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.init(title, hint: hint, systemImage: systemImage, role: role,
                  showChevron: showChevron, accessibilityValue: accessibilityValue,
                  onTap: onTap) { EmptyView() }
    }
}

/// 設定列右側的值文字（15pt、neutral-500）。搭配 `showChevron: true` 呈現「值＋chevron」。
public struct SettingsValue: View {
    private let text: Text
    public init(_ text: Text) { self.text = text }
    public var body: some View {
        text
            .font(TLFont.zh(TLFont.rowTitle))
            .foregroundStyle(TLColor.neutral500)
    }
}

/// 開關型設定列。底層是 `Toggle` + `TLSwitchToggleStyle`，保留 switch 無障礙語意。
/// `hint` 為標題後方小灰字（如「含震動」），但**不計入 switch 的無障礙標籤**（標籤只用標題）。
public struct SettingsToggleRow: View {
    private let title: Text
    private let hint: Text?
    @Binding private var isOn: Bool

    public init(_ title: Text, hint: Text? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.hint = hint
        self._isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                title
                    .font(TLFont.zh(TLFont.rowTitle))
                    .foregroundStyle(TLColor.text)
                if let hint {
                    hint
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                }
            }
        }
        .toggleStyle(.tlSwitch)
        .accessibilityLabel(title)   // 讓 switch 標籤只含標題、排除 hint（UITest 用 switches["聲音"] 查得到）
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: TLSize.row)
    }
}
