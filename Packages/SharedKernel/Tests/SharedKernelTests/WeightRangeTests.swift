import Testing

@testable import SharedKernel

struct WeightRangeTests {
    @Test func upperBoundDiffersByUnit() {
        #expect(WeightRange.upperBound(for: .kg) == 500)
        #expect(WeightRange.upperBound(for: .lb) == 1100)
    }

    /// 上限跟單位脫鉤是原本的 bug（舊行為 lb 模式實際上限 300 lb ＝ 136 kg，
    /// 比 kg 模式的 300 kg 還低一半以上）。1100 lb ＝ 498.95 kg，跟 500 kg
    /// 差不到 1 公斤，是刻意取的整數。
    @Test func upperBoundsAreComparableAcrossUnits() {
        let kgCap = Weight(value: WeightRange.upperBound(for: .kg), unit: .kg)
        let lbCap = Weight(value: WeightRange.upperBound(for: .lb), unit: .lb)
        #expect(abs(lbCap.kilograms - kgCap.kilograms) < 5)
    }

    @Test func valuesStartAtZeroAndReachUpperBound() {
        let values = WeightRange.values(for: .kg, step: 2.5)
        #expect(values.first == 0)
        #expect(values.last == 500)
    }

    @Test func valuesFollowStep() {
        #expect(WeightRange.values(for: .kg, step: 100) == [0, 100, 200, 300, 400, 500])
    }

    /// 級距是使用者偏好，0 或負數不該讓清單變成空的或無窮迴圈。
    @Test func nonPositiveStepFallsBackToOne() {
        #expect(WeightRange.values(for: .kg, step: 0).count == 501)
        #expect(WeightRange.values(for: .kg, step: -5).count == 501)
    }

    /// 細級距清單會很長，但要真的能涵蓋常用重量。
    @Test func fineStepStillCoversRange() {
        let values = WeightRange.values(for: .kg, step: 0.17)
        #expect(values.count > 2000)
        #expect(values.last! <= 500)
    }

    @Test func clampedKeepsValueInRange() {
        #expect(WeightRange.clamped(-10, unit: .kg) == 0)
        #expect(WeightRange.clamped(600, unit: .kg) == 500)
        #expect(WeightRange.clamped(600, unit: .lb) == 600)
        #expect(WeightRange.clamped(1200, unit: .lb) == 1100)
        #expect(WeightRange.clamped(62.5, unit: .kg) == 62.5)
    }
}
