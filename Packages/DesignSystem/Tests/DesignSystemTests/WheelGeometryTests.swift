import CoreGraphics
import Testing

@testable import DesignSystem

/// 滾輪的幾何運算。座標約定見 `WheelGeometry`：offset 往下為正，
/// 所以「往上滑（看更大的值）」＝ 負的 offset。
struct WheelGeometryTests {
    private let geo = WheelGeometry(rowHeight: 44)
    /// 票上的例子：級距 5、目前 20 → anchor 是 index 4（0,5,10,15,20,…）。
    /// 長度比照實際重量值域（`WeightRange`），長清單才測得到「甩很遠」。
    private let values = Array(stride(from: 0.0, through: 500.0, by: 5))

    // MARK: - 渲染窗口跟著拖曳走（票的核心）

    @Test func windowIsCentredOnAnchorWhenIdle() {
        // 沒拖時就是舊行為：anchor ±3（多畫一圈備用，viewport 只看得到 ±2）。
        #expect(geo.visibleIndices(offset: 0, anchor: 4, count: values.count) == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test func windowFollowsTheDragSoNewValuesScrollIn() {
        // 往上拖 4 格：高亮帶已經停在 index 8，窗口整個跟著移過去。
        let rows = geo.visibleIndices(offset: -44 * 4, anchor: 4, count: values.count)
        #expect(rows.contains(8))
        #expect(rows.contains(11))   // 舊版寫死 anchor±2，index 6 之後就沒東西可畫了
        #expect(!rows.contains(4))
    }

    @Test func windowClampsToTheEndsOfTheList() {
        #expect(geo.visibleIndices(offset: 0, anchor: 0, count: values.count) == [0, 1, 2, 3])
        let last = values.count - 1
        #expect(geo.visibleIndices(offset: 0, anchor: last, count: values.count).last == last)
    }

    @Test func emptyListDrawsNothing() {
        #expect(geo.visibleIndices(offset: 0, anchor: 0, count: 0).isEmpty)
    }

    // MARK: - 慣性

    @Test func settleUsesPredictedTranslationNotTheFingerDistance() {
        // 手指只移動 100pt，但甩出去預估會滑 880pt ＝ 20 格。
        #expect(geo.settleIndex(anchor: 4, predictedTranslation: -880, count: values.count) == 24)
    }

    @Test func settleRoundsToTheNearestRowAndClampsToBounds() {
        #expect(geo.settleIndex(anchor: 4, predictedTranslation: -60, count: values.count) == 5)
        #expect(geo.settleIndex(anchor: 4, predictedTranslation: -20, count: values.count) == 4)
        #expect(geo.settleIndex(anchor: 4, predictedTranslation: 9999, count: values.count) == 0)
        #expect(geo.settleIndex(anchor: 4, predictedTranslation: -9999, count: values.count) == values.count - 1)
    }

    @Test func settleDurationGrowsWithDistanceButIsCapped() {
        #expect(WheelGeometry.settleDuration(steps: 1) < WheelGeometry.settleDuration(steps: 20))
        #expect(WheelGeometry.settleDuration(steps: 500) == 0.6)
        #expect(WheelGeometry.settleDuration(steps: -20) == WheelGeometry.settleDuration(steps: 20))
    }

    // MARK: - 邊界不拖進空白

    @Test func offsetCannotDragPastEitherEnd() {
        // 往下拖（看更小的值）最多到 index 0：4 格 × 44。
        #expect(geo.clampedOffset(9999, anchor: 4, count: values.count) == CGFloat(44 * 4))
        // 往上拖最多到最後一格。
        let toLast = -44 * CGFloat(values.count - 1 - 4)
        #expect(geo.clampedOffset(-9999, anchor: 4, count: values.count) == toLast)
        // 範圍內不動它。
        #expect(geo.clampedOffset(-50, anchor: 4, count: values.count) == -50)
    }

    // MARK: - 字級／顏色吃「離高亮帶的距離」

    @Test func fontSizeInterpolatesAlongTheDesignLadder() {
        #expect(WheelGeometry.fontSize(distance: 0) == 28)
        #expect(WheelGeometry.fontSize(distance: 1) == 20)
        #expect(WheelGeometry.fontSize(distance: -1) == 20)
        #expect(WheelGeometry.fontSize(distance: 2) == 17)
        #expect(WheelGeometry.fontSize(distance: 5) == 17)
        // 捲到一半的值介於兩階之間 —— 舊版吃靜態 k，放開前字級不會變。
        #expect(WheelGeometry.fontSize(distance: 0.5) == 24)
    }

    @Test func liveIndexTracksWhicheverRowSitsInTheBand() {
        #expect(geo.liveIndex(offset: 0, anchor: 4, count: values.count) == 4)
        #expect(geo.liveIndex(offset: -44 * 3, anchor: 4, count: values.count) == 7)
        #expect(geo.liveIndex(offset: 44 * 99, anchor: 4, count: values.count) == 0)
    }
}
