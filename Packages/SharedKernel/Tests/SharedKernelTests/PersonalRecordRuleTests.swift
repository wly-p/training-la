import Foundation
import Testing

@testable import SharedKernel

/// PR 判定規則的案例表。這一份是**兩個呼叫端共同的契約**——
/// Training 的完成摘要與 History 的趨勢圖都走同一支函式，所以只要在這裡釘住就夠。
struct PersonalRecordRuleTests {
    private func kg(_ v: Double) -> Weight { Weight(value: v, unit: .kg) }
    private func perf(_ v: Double, _ reps: Int) -> PersonalRecordRule.Performance {
        .init(weight: kg(v), reps: reps)
    }

    @Test func firstEverIsAlwaysAPR() {
        #expect(PersonalRecordRule.evaluate(perf(60, 5), against: []) == .firstEver)
    }

    @Test func heavierThanAnythingBeforeIsNewWeight() {
        let history = [perf(90, 8), perf(85, 10)]
        #expect(PersonalRecordRule.evaluate(perf(95, 3), against: history) == .newWeight)
    }

    /// 舊的兩套規則都在這個案例上答錯：嚴格版說沒有 PR（100kg 與 5 下都沒出現過），
    /// 寬鬆版說有 PR 但理由是「5 > 0」。正解是「100 > 90，重量創新高」。
    @Test func heavierAtDifferentRepsIsStillNewWeight() {
        #expect(PersonalRecordRule.evaluate(perf(100, 5), against: [perf(90, 8)]) == .newWeight)
    }

    @Test func sameWeightMoreRepsIsNewRepsAtWeight() {
        let history = [perf(100, 5), perf(100, 4)]
        #expect(PersonalRecordRule.evaluate(perf(100, 6), against: history) == .newRepsAtWeight)
    }

    @Test func sameWeightFewerRepsIsNotAPR() {
        #expect(PersonalRecordRule.evaluate(perf(100, 4), against: [perf(100, 6)]) == nil)
    }

    @Test func lighterThanBestIsNotAPR() {
        #expect(PersonalRecordRule.evaluate(perf(80, 12), against: [perf(100, 5)]) == nil)
    }

    /// 混單位不能靠裸數字比：100 lb（約 45.4 kg）不該勝過 100 kg。
    @Test func mixedUnitsCompareByActualWeight() {
        let historyKg = [PersonalRecordRule.Performance(weight: kg(100), reps: 5)]
        let lb100 = PersonalRecordRule.Performance(weight: Weight(value: 100, unit: .lb), reps: 5)
        #expect(PersonalRecordRule.evaluate(lb100, against: historyKg) == nil)

        let historyLb = [lb100]
        let kg100 = PersonalRecordRule.Performance(weight: kg(100), reps: 5)
        #expect(PersonalRecordRule.evaluate(kg100, against: historyLb) == .newWeight)
    }

    /// 同重量視為同一格，即使單位不同（100 kg vs 220.46 lb）。
    @Test func sameWeightAcrossUnitsSharesTheRepsBucket() {
        let lbEquivalent = Weight(value: 100 * 2.20462262185, unit: .lb)
        let history = [PersonalRecordRule.Performance(weight: lbEquivalent, reps: 5)]
        #expect(PersonalRecordRule.evaluate(perf(100, 6), against: history) == .newRepsAtWeight)
        #expect(PersonalRecordRule.evaluate(perf(100, 4), against: history) == nil)
    }

    @Test func representativeIsHeaviestThenMostReps() {
        let sets = [perf(60, 12), perf(100, 3), perf(100, 5), perf(80, 8)]
        #expect(PersonalRecordRule.representative(of: sets) == perf(100, 5))
    }

    @Test func representativeOfEmptyIsNil() {
        #expect(PersonalRecordRule.representative(of: []) == nil)
    }
}

/// 各追蹤模式的 PR 判定（B2-model）。
struct MeasurementPersonalRecordTests {
    private let kg = { (v: Double) in Weight(value: v, unit: .kg) }

    @Test func modesAreNeverComparedAgainstEachOther() {
        // 歷史全是時間模式，今天是重量模式 → 這個模式的第一筆，不是「沒破紀錄」
        let history: [SetMeasurement] = [.duration(seconds: 120), .duration(seconds: 90)]

        let kind = PersonalRecordRule.evaluateMeasurement(
            .weightReps(weight: kg(100), reps: 5), against: history
        )

        #expect(kind == .firstEver)
    }

    @Test func longerHoldIsAPersonalRecord() {
        let history: [SetMeasurement] = [.duration(seconds: 60), .duration(seconds: 90)]

        #expect(PersonalRecordRule.evaluateMeasurement(.duration(seconds: 120), against: history) == .newDuration)
        #expect(PersonalRecordRule.evaluateMeasurement(.duration(seconds: 90), against: history) == nil)
    }

    @Test func fartherDistanceIsAPersonalRecord() {
        let history: [SetMeasurement] = [.distance(meters: 5000)]

        #expect(PersonalRecordRule.evaluateMeasurement(.distance(meters: 5001), against: history) == .newDistance)
        #expect(PersonalRecordRule.evaluateMeasurement(.distance(meters: 4999), against: history) == nil)
    }

    @Test func moreRepsIsAPersonalRecordInRepsOnlyMode() {
        let history: [SetMeasurement] = [.reps(12), .reps(10)]

        #expect(PersonalRecordRule.evaluateMeasurement(.reps(13), against: history) == .newReps)
        #expect(PersonalRecordRule.evaluateMeasurement(.reps(12), against: history) == nil)
    }

    /// 自體重加重沿用重量模式的規則（比的是加掛了多少）。
    @Test func bodyweightPlusUsesTheWeightRules() {
        let history: [SetMeasurement] = [.bodyweightPlus(added: kg(10), reps: 5)]

        #expect(PersonalRecordRule.evaluateMeasurement(
            .bodyweightPlus(added: kg(15), reps: 3), against: history) == .newWeight)
        #expect(PersonalRecordRule.evaluateMeasurement(
            .bodyweightPlus(added: kg(10), reps: 8), against: history) == .newRepsAtWeight)
    }

    @Test func representativePicksTheBestWithinTheMode() {
        let sets: [SetMeasurement] = [.duration(seconds: 30), .duration(seconds: 95), .duration(seconds: 60)]

        #expect(PersonalRecordRule.representativeMeasurement(of: sets) == .duration(seconds: 95))
    }
}

/// 分項總計：各模式各自累計，不互相換算（B2-model）。
struct SessionTotalsTests {
    @Test func nonWeightModesAreNotSilentlyCountedAsZeroVolume() {
        var totals = SessionTotals()
        totals.add(.weightReps(weight: Weight(value: 100, unit: .kg), reps: 5))
        totals.add(.duration(seconds: 90))
        totals.add(.distance(meters: 5000))
        totals.add(.reps(12))

        #expect(totals.volumeKilograms == 500)
        #expect(totals.durationSeconds == 90)
        #expect(totals.distanceMeters == 5000)
        #expect(totals.repsOnly == 12)
        #expect(totals.hasNonWeightWork)
    }

    /// 自體重加重只算加掛的部分——全專案沒有使用者體重這個概念。
    @Test func bodyweightPlusCountsOnlyTheAddedLoad() {
        var totals = SessionTotals()
        totals.add(.bodyweightPlus(added: Weight(value: 20, unit: .kg), reps: 5))

        #expect(totals.volumeKilograms == 100)
    }

    @Test func aPureWeightSessionHasNothingElseToReport() {
        var totals = SessionTotals()
        totals.add(.weightReps(weight: Weight(value: 60, unit: .kg), reps: 10))

        #expect(totals.hasNonWeightWork == false)
    }

    @Test func meetsTargetIsNilAcrossDifferentModes() {
        #expect(SetMeasurementComparison.meetsTarget(
            .duration(seconds: 90), target: .weightReps(weight: Weight(value: 60, unit: .kg), reps: 8)
        ) == nil)
    }

    @Test func meetsTargetComparesEachDimension() {
        let target = SetMeasurement.weightReps(weight: Weight(value: 100, unit: .kg), reps: 5)

        #expect(SetMeasurementComparison.meetsTarget(
            .weightReps(weight: Weight(value: 100, unit: .kg), reps: 5), target: target) == true)
        #expect(SetMeasurementComparison.meetsTarget(
            .weightReps(weight: Weight(value: 100, unit: .kg), reps: 4), target: target) == false)
        #expect(SetMeasurementComparison.meetsTarget(
            .duration(seconds: 100), target: .duration(seconds: 90)) == true)
    }
}
