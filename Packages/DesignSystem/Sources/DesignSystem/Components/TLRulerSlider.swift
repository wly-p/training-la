import SwiftUI

/// 水平刻度尺（handoff-15 G 節）：取代垂直滾輪做微調，高度只要一半。
///
/// 中央 accent 刻線對齊當前值，下方五個標籤（間距＝級距、範圍＝當前值 ±2 級距），
/// 當前值那個標籤用 accent-700 加粗。拖曳左右微調。
///
/// 跟 `ValuePicker` 的差別：那個是「從一長串值裡選一個」，這個是「在當前值附近推一推」。
/// 能力值編輯已經有大數字輸入負責跳到任意值，剩下的只需要微調。
public struct TLRulerSlider: View {
    @Binding private var value: Double
    private let step: Double
    private let range: ClosedRange<Double>

    /// 拖曳中的累計位移；放開才收斂回 `value`，中途不寫回避免每動一點就觸發外部副作用。
    @State private var dragOffset: CGFloat = 0

    /// 一個級距對應的水平距離。太小會讓拖曳過於敏感、太大則要拖很遠。
    private let pointsPerStep: CGFloat = 44

    public init(value: Binding<Double>, step: Double, range: ClosedRange<Double>) {
        self._value = value
        self.step = step > 0 ? step : 1
        self.range = range
    }

    /// 拖曳中即時顯示的值（尚未寫回 binding）。
    private var liveValue: Double {
        let stepsMoved = Double(-dragOffset / pointsPerStep)
        return clamp(value + stepsMoved.rounded() * step)
    }

    private func clamp(_ raw: Double) -> Double {
        min(max(raw, range.lowerBound), range.upperBound)
    }

    /// 五個標籤：當前值置中、左右各兩個級距。超出值域的不畫（清單邊緣不要出現假刻度）。
    private var labels: [Double] {
        (-2...2).map { liveValue + Double($0) * step }.filter { range.contains($0) }
    }

    public var body: some View {
        VStack(spacing: 6) {
            ticks
            labelRow
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { dragOffset = $0.translation.width }
                .onEnded { _ in
                    value = liveValue
                    dragOffset = 0
                }
        )
        .accessibilityElement()
        .accessibilityValue(Text(verbatim: TLNumberField.format(liveValue)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = clamp(value + step)
            case .decrement: value = clamp(value - step)
            @unknown default: break
            }
        }
    }

    /// 刻線：每個級距一根長的、中間補一根短的，中央那根是 accent。
    private var ticks: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(-8...8, id: \.self) { index in
                let isMajor = index.isMultiple(of: 2)
                let isCenter = index == 0
                Rectangle()
                    .fill(isCenter ? TLColor.accent : TLColor.neutral400)
                    .frame(
                        width: isCenter ? 2.5 : 1,
                        height: isCenter ? 26 : (isMajor ? 18 : 10)
                    )
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 26)
    }

    private var labelRow: some View {
        HStack(spacing: 0) {
            ForEach(labels, id: \.self) { label in
                let isCurrent = abs(label - liveValue) < 0.0001
                Text(verbatim: TLNumberField.format(label))
                    .font(TLFont.zh(11.5, isCurrent ? .bold : .regular))
                    .foregroundStyle(isCurrent ? TLColor.accent700 : TLColor.neutral500)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
