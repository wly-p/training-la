import SwiftUI

/// 模板 8 變體：兩個數值並排的選擇器（設計稿 4a「08 · 數值選擇器」：重量／次數共用一個容器、
/// 一條高亮帶、一排快捷）。單一數值的情境仍用 `ValuePicker`；這個給「重量 ＋ 次數」一次編兩個值用
/// （範本逐組編輯 11b）。
///
/// 兩欄滾輪本體（渲染窗口、手勢、慣性）在 `WheelColumn`，跟 `ValuePicker` 共用同一份。
public struct DualValuePicker: View {
    public typealias QuickAction = ValuePicker.QuickAction

    @Binding private var primaryValue: Double
    @Binding private var secondaryValue: Double
    private let primaryValues: [Double]
    private let secondaryValues: [Double]
    private let primaryKicker: String
    private let secondaryKicker: String
    private let primaryFormat: (Double) -> String
    private let secondaryFormat: (Double) -> String
    private let quickActions: [QuickAction]

    private let rowHeight: CGFloat = 44

    public init(
        primaryValue: Binding<Double>,
        primaryValues: [Double],
        primaryKicker: String,
        primaryFormat: @escaping (Double) -> String = ValuePicker.defaultFormat,
        secondaryValue: Binding<Double>,
        secondaryValues: [Double],
        secondaryKicker: String,
        secondaryFormat: @escaping (Double) -> String = ValuePicker.defaultFormat,
        quickActions: [QuickAction] = []
    ) {
        self._primaryValue = primaryValue
        self.primaryValues = primaryValues
        self.primaryKicker = primaryKicker
        self.primaryFormat = primaryFormat
        self._secondaryValue = secondaryValue
        self.secondaryValues = secondaryValues
        self.secondaryKicker = secondaryKicker
        self.secondaryFormat = secondaryFormat
        self.quickActions = quickActions
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                kickerText(primaryKicker)
                Spacer(minLength: TLSpace.gapS)
                kickerText(secondaryKicker)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(TLColor.neutral300)
                    .frame(height: rowHeight)
                HStack(spacing: 0) {
                    WheelColumn(
                        value: $primaryValue, values: primaryValues,
                        format: primaryFormat, rowHeight: rowHeight
                    )
                    WheelColumn(
                        value: $secondaryValue, values: secondaryValues,
                        format: secondaryFormat, rowHeight: rowHeight
                    )
                }
            }
            .frame(height: rowHeight * 5)
            .clipped()
            if !quickActions.isEmpty { quickRow }
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }

    private func kickerText(_ s: String) -> some View {
        Text(s)
            .font(TLFont.zh(TLFont.kicker, .semibold))
            .tracking(TLFont.kickerTracking)
            .textCase(.uppercase)
            .foregroundStyle(TLColor.neutral500)
    }

    private var quickRow: some View {
        let spacing = TLSpace.gapS
        let totalFlex = quickActions.reduce(0) { $0 + $1.flex }
        return GeometryReader { geo in
            let available = geo.size.width - spacing * CGFloat(quickActions.count - 1)
            HStack(spacing: spacing) {
                ForEach(quickActions) { action in
                    Button(action: action.action) {
                        Text(action.label)
                            .font(TLFont.zh(TLFont.rowTitle, .semibold))
                            .foregroundStyle(TLColor.accent700)
                            .frame(width: max(available * action.flex / totalFlex, 0))
                            .padding(.vertical, 12)
                            .background(Capsule().fill(TLColor.neutral100))
                            .overlay(Capsule().strokeBorder(TLColor.text.opacity(0.10), lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 44)
    }
}
