import SwiftUI

/// 模板 8 變體：兩個數值並排的選擇器（設計稿 4a「08 · 數值選擇器」：重量／次數共用一個容器、
/// 一條高亮帶、一排快捷）。單一數值的情境仍用 `ValuePicker`；這個給「重量 ＋ 次數」一次編兩個值用
/// （範本逐組編輯 11b）。
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

    @State private var primaryDrag: CGFloat = 0
    @State private var secondaryDrag: CGFloat = 0

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
                    column(value: $primaryValue, values: primaryValues, format: primaryFormat, dragOffset: $primaryDrag)
                    column(value: $secondaryValue, values: secondaryValues, format: secondaryFormat, dragOffset: $secondaryDrag)
                }
            }
            .frame(height: rowHeight * 5)
            .clipped()
            if !quickActions.isEmpty { quickRow }
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
        .sensoryFeedback(.selection, trigger: liveIndex(value: primaryValue, drag: primaryDrag, in: primaryValues))
        .sensoryFeedback(.selection, trigger: liveIndex(value: secondaryValue, drag: secondaryDrag, in: secondaryValues))
    }

    private func kickerText(_ s: String) -> some View {
        Text(s)
            .font(TLFont.zh(TLFont.kicker, .semibold))
            .tracking(TLFont.kickerTracking)
            .textCase(.uppercase)
            .foregroundStyle(TLColor.neutral500)
    }

    private func column(
        value: Binding<Double>, values: [Double], format: @escaping (Double) -> String, dragOffset: Binding<CGFloat>
    ) -> some View {
        let currentIndex = index(of: value.wrappedValue, in: values)
        return ZStack {
            ForEach(-2...2, id: \.self) { k in
                let idx = currentIndex + k
                if values.indices.contains(idx) {
                    Text(format(values[idx]))
                        .font(TLFont.display(fontSize(for: k)))
                        .foregroundStyle(color(for: k))
                        .offset(y: CGFloat(k) * rowHeight + dragOffset.wrappedValue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { dragOffset.wrappedValue = $0.translation.height }
                .onEnded { g in
                    let steps = Int((-g.translation.height / rowHeight).rounded())
                    let newIndex = min(max(currentIndex + steps, 0), values.count - 1)
                    value.wrappedValue = values[newIndex]
                    withAnimation(.easeOut(duration: 0.15)) { dragOffset.wrappedValue = 0 }
                }
        )
    }

    private func index(of value: Double, in values: [Double]) -> Int {
        values.firstIndex(of: value) ?? values.firstIndex(where: { $0 >= value }) ?? 0
    }

    private func liveIndex(value: Double, drag: CGFloat, in values: [Double]) -> Int {
        let steps = Int((-drag / rowHeight).rounded())
        return min(max(index(of: value, in: values) + steps, 0), values.count - 1)
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

    private func fontSize(for k: Int) -> CGFloat {
        switch abs(k) {
        case 0: return 28
        case 1: return 20
        default: return 17
        }
    }
    private func color(for k: Int) -> Color {
        switch abs(k) {
        case 0: return TLColor.neutral900
        case 1: return TLColor.neutral500
        default: return TLColor.neutral400
        }
    }
}
