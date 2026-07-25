import SwiftUI

/// 模板 8：數值選擇器（解決誤按）。滾輪式選值 ＋ 下方快捷。
/// 重量、次數、組數、休息秒數全部共用這一個元件。
///
/// - 中央高亮帶：44pt 高、圓角 16、`neutral-300`
/// - 中央值：28pt Caprasimo、`neutral-900`
/// - 上下各兩階遞減：20pt `neutral-500`（±1）→ 17pt `neutral-400`（±2）
/// - 下方一排快捷 capsule（如 `−2.5` / `+2.5` / `同上組`）
public struct ValuePicker: View {
    /// 快捷鍵。`flex` 控制寬度比例（README：−2.5 : +2.5 : 同上組 = 1 : 1 : 1.4）。
    public struct QuickAction: Identifiable {
        public let id = UUID()
        public let label: String
        public let flex: CGFloat
        public let action: () -> Void
        public init(_ label: String, flex: CGFloat = 1, action: @escaping () -> Void) {
            self.label = label
            self.flex = flex
            self.action = action
        }
    }

    @Binding private var value: Double
    private let values: [Double]
    private let kicker: String?
    private let format: (Double) -> String
    private let quickActions: [QuickAction]

    @State private var dragOffset: CGFloat = 0

    private let rowHeight: CGFloat = 44

    public init(
        value: Binding<Double>,
        values: [Double],
        kicker: String? = nil,
        format: @escaping (Double) -> String = ValuePicker.defaultFormat,
        quickActions: [QuickAction] = []
    ) {
        self._value = value
        self.values = values
        self.kicker = kicker
        self.format = format
        self.quickActions = quickActions
    }

    /// 預設格式：整數不帶小數、其餘去掉多餘 0（60.0→60、57.5→57.5）。
    /// `nonisolated`：讓它能當作預設參數值（否則會繼承 View 的 MainActor 隔離）。
    public nonisolated static func defaultFormat(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }

    private var currentIndex: Int {
        values.firstIndex(of: value) ?? values.firstIndex(where: { $0 >= value }) ?? 0
    }

    /// 拖曳過程中即時對應到的 index（含未放開的位移），用於觸覺與吸附。
    private var liveIndex: Int {
        let steps = Int((-dragOffset / rowHeight).rounded())
        return min(max(currentIndex + steps, 0), values.count - 1)
    }

    public var body: some View {
        VStack(spacing: 16) {
            if let kicker {
                Text(kicker)
                    .font(TLFont.zh(TLFont.kicker, .semibold))
                    .tracking(TLFont.kickerTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(TLColor.neutral500)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            wheel
            if !quickActions.isEmpty { quickRow }
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
        .sensoryFeedback(.selection, trigger: liveIndex)
    }

    private var wheel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TLColor.neutral300)
                .frame(height: rowHeight)

            ForEach(-2...2, id: \.self) { k in
                let idx = currentIndex + k
                if values.indices.contains(idx) {
                    Text(format(values[idx]))
                        .font(TLFont.display(fontSize(for: k)))
                        .foregroundStyle(color(for: k))
                        .offset(y: CGFloat(k) * rowHeight + dragOffset)
                }
            }
        }
        .frame(height: rowHeight * 5)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { dragOffset = $0.translation.height }
                .onEnded { g in
                    let steps = Int((-g.translation.height / rowHeight).rounded())
                    let newIndex = min(max(currentIndex + steps, 0), values.count - 1)
                    value = values[newIndex]
                    withAnimation(.easeOut(duration: 0.15)) { dragOffset = 0 }
                }
        )
    }

    private var quickRow: some View {
        // 依 flex 比例分配寬度（README：−2.5 : +2.5 : 同上組 = 1 : 1 : 1.4）。
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

    // ±0 中央 28pt neutral900、±1 20pt neutral500、±2 17pt neutral400。
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
