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
