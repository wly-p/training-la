import Foundation
import SharedKernel
import Testing
import TrainingDomain

@testable import TrainingPresentation

struct WeightDisplayTests {
    @Test func valueDropsTrailingZeroForWholeNumbers() {
        #expect(WeightDisplay.value(60) == "60")
    }

    @Test func valueKeepsDecimalForFractionalValues() {
        #expect(WeightDisplay.value(62.5) == "62.5")
    }

    /// 顯示單位由呼叫端（偏好）決定，不是照抄紀錄自己的單位。
    @Test func weightAppendsTheDisplayUnitRawValue() {
        #expect(WeightDisplay.weight(Weight(value: 60, unit: .kg), in: .kg) == "60kg")
        #expect(WeightDisplay.weight(Weight(value: 62.5, unit: .lb), in: .lb) == "62.5lb")
    }

    /// 紀錄的單位跟偏好不同時要換算——這正是「切成 lb 幾乎是無效操作」要修掉的行為。
    @Test func weightConvertsWhenTheRecordUsesADifferentUnit() {
        #expect(WeightDisplay.weight(Weight(value: 60, unit: .kg), in: .lb).hasSuffix("lb"))
        #expect(WeightDisplay.weight(Weight(value: 220.462, unit: .lb), in: .kg).hasPrefix("100"))
    }

    @Test func summaryReturnsEmptyStringForNoSets() {
        #expect(WeightDisplay.summary(of: [], in: .kg) == "")
    }

    @Test func summaryCollapsesRepsWhenWeightIsSame() {
        let exerciseId = UUID()
        let sets = [8, 8, 6].enumerated().map { index, reps in
            WorkoutSet(id: UUID(), exerciseId: exerciseId, exerciseIndex: 0, setIndex: index, measurement: .weightReps(weight: Weight(value: 60, unit: .kg), reps: reps))
        }

        #expect(WeightDisplay.summary(of: sets, in: .kg) == "60kg × 8, 8, 6")
    }

    @Test func summaryListsEachSetWhenWeightsDiffer() {
        let exerciseId = UUID()
        let sets = [
            WorkoutSet(id: UUID(), exerciseId: exerciseId, exerciseIndex: 0, setIndex: 0, measurement: .weightReps(weight: Weight(value: 60, unit: .kg), reps: 8)),
            WorkoutSet(id: UUID(), exerciseId: exerciseId, exerciseIndex: 0, setIndex: 1, measurement: .weightReps(weight: Weight(value: 65, unit: .kg), reps: 6)),
        ]

        #expect(WeightDisplay.summary(of: sets, in: .kg) == "60kg×8, 65kg×6")
    }
}
