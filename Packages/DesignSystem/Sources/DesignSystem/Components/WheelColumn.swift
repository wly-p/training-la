import SwiftUI

/// 滾輪的純幾何運算。`WheelColumn` 是 View 測不動，所以會出錯的數學全部搬到這裡。
///
/// 座標約定：`anchor` ＝ 手勢開始時停在高亮帶上的那一格；`offset` ＝ 手指往下拖的位移
/// （跟 `DragGesture.translation.height` 同號，往下為正）。第 i 格畫在
/// `y = (i - anchor) * rowHeight + offset`，所以停在高亮帶上的是第 `anchor + centre` 格。
struct WheelGeometry {
    let rowHeight: CGFloat

    /// 高亮帶上下各畫幾格。viewport 只有 5 格高，多畫一圈是為了讓捲進來的值
    /// 已經在畫面外準備好，不會憑空出現。
    private let renderRadius: CGFloat = 3

    /// 高亮帶目前停在 anchor 往後第幾格（可為小數、可為負）。
    func centre(offset: CGFloat) -> CGFloat {
        rowHeight > 0 ? -offset / rowHeight : 0
    }

    /// 某一格離高亮帶多遠（格數）。字級與顏色都吃這個值，所以捲進中央的值會邊捲邊變大。
    func distance(index: Int, anchor: Int, offset: CGFloat) -> CGFloat {
        CGFloat(index - anchor) - centre(offset: offset)
    }

    /// 目前要畫的**絕對 index**。窗口跟著拖曳走 —— 這就是「一次滑動能連續換值」的關鍵：
    /// 舊版寫死 `anchor ± 2`，整個手勢期間只有那 5 個數字在平移，拖再遠也沒有新值捲進來。
    ///
    /// 回傳絕對 index 而非相對 k，是要拿它當 `ForEach` 的 identity：落地時 anchor 會換人，
    /// 相對 k 會讓同一個 view 突然代表另一個數字，整排錯位重畫。
    func visibleIndices(offset: CGFloat, anchor: Int, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let c = centre(offset: offset)
        let lower = max(Int((CGFloat(anchor) + c - renderRadius).rounded(.down)), 0)
        let upper = min(Int((CGFloat(anchor) + c + renderRadius).rounded(.up)), count - 1)
        return lower <= upper ? Array(lower...upper) : []
    }

    /// 拖曳中夾住位移，讓高亮帶停不出值域外 —— 否則會拖出一段空白（超界的格子直接不畫）。
    func clampedOffset(_ raw: CGFloat, anchor: Int, count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let towardsFirst = CGFloat(anchor) * rowHeight               // 往下拖到第 0 格為止
        let towardsLast = -CGFloat(count - 1 - anchor) * rowHeight   // 往上拖到最後一格為止
        return min(max(raw, towardsLast), towardsFirst)
    }

    /// 放開後落在哪一格。吃 `predictedEndTranslation` 而不是 `translation`，
    /// 甩一下才能滑過很多格（0…500kg / 2.5 級距＝200 格，只走手指移動距離的話要甩到天荒地老）。
    func settleIndex(anchor: Int, predictedTranslation: CGFloat, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let steps = rowHeight > 0 ? Int((-predictedTranslation / rowHeight).rounded()) : 0
        return min(max(anchor + steps, 0), count - 1)
    }

    /// 拖曳中對應到的 index（觸覺回饋用：每過一格震一下）。
    func liveIndex(offset: CGFloat, anchor: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(anchor + Int(centre(offset: offset).rounded()), 0), count - 1)
    }

    /// 收斂動畫時長：走一格就快、甩很多格就給它慢慢煞。
    static func settleDuration(steps: Int) -> Double {
        min(0.6, 0.15 + Double(abs(steps)) * 0.012)
    }

    /// 28pt（高亮帶）→ 20pt（±1）→ 17pt（±2 以外）線性內插。階梯值同設計稿模板 8。
    static func fontSize(distance: CGFloat) -> CGFloat {
        let d = min(abs(distance), 2)
        return d <= 1 ? 28 - 8 * d : 20 - 3 * (d - 1)
    }

    /// 顏色取最近的一階（設計稿只有三個灰階，內插會跑出稿上沒有的顏色）。
    static func color(distance: CGFloat) -> Color {
        switch min(Int(abs(distance).rounded()), 2) {
        case 0: TLColor.neutral900
        case 1: TLColor.neutral500
        default: TLColor.neutral400
        }
    }
}

/// 模板 8 的滾輪本體：一欄數字 ＋ 拖曳手勢。高亮帶由呼叫端畫在底下
/// （`DualValuePicker` 是一條橫跨兩欄的帶子，`ValuePicker` 只有一欄）。
///
/// `ValuePicker` 與 `DualValuePicker` 原本各自複製了一份同樣的滾輪，改一次要改兩邊；
/// 併成這一個之後兩邊行為一定一致。
struct WheelColumn: View {
    @Binding var value: Double
    let values: [Double]
    let format: (Double) -> String
    var rowHeight: CGFloat = 44

    @State private var dragOffset: CGFloat = 0
    /// 只在拖曳中更新：收斂動畫期間不要一格震一下（一次甩 20 格會震到手麻）。
    @State private var hapticIndex: Int = 0

    private var geometry: WheelGeometry { WheelGeometry(rowHeight: rowHeight) }

    /// 手勢起點：目前值在清單裡的位置。
    private var anchor: Int {
        values.firstIndex(of: value) ?? values.firstIndex(where: { $0 >= value }) ?? 0
    }

    var body: some View {
        let geo = geometry
        let anchorIndex = anchor
        return ZStack {
            ForEach(geo.visibleIndices(offset: dragOffset, anchor: anchorIndex, count: values.count), id: \.self) { index in
                let d = geo.distance(index: index, anchor: anchorIndex, offset: dragOffset)
                Text(format(values[index]))
                    .font(TLFont.display(WheelGeometry.fontSize(distance: d)))
                    .foregroundStyle(WheelGeometry.color(distance: d))
                    .offset(y: d * rowHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(drag(geo: geo, anchor: anchorIndex))
        .sensoryFeedback(.selection, trigger: hapticIndex)
    }

    private func drag(geo: WheelGeometry, anchor: Int) -> some Gesture {
        DragGesture()
            .onChanged { g in
                dragOffset = geo.clampedOffset(g.translation.height, anchor: anchor, count: values.count)
                hapticIndex = geo.liveIndex(offset: dragOffset, anchor: anchor, count: values.count)
            }
            .onEnded { g in
                let newIndex = geo.settleIndex(
                    anchor: anchor, predictedTranslation: g.predictedEndTranslation.height, count: values.count
                )
                guard values.indices.contains(newIndex) else { return }
                // 先換 anchor、同時補償位移讓畫面停在原地（每一格的 y 完全不變），再動畫收到 0。
                // 少了這步補償，值一換就會先跳到新位置再滑回來。
                let delta = newIndex - anchor
                value = values[newIndex]
                dragOffset = g.translation.height + CGFloat(delta) * rowHeight
                hapticIndex = newIndex
                withAnimation(.easeOut(duration: WheelGeometry.settleDuration(steps: delta))) {
                    dragOffset = 0
                }
            }
    }
}
