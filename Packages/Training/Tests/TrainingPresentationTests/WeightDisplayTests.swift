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

    @Test func weightAppendsUnitRawValue() {
        #expect(WeightDisplay.weight(Weight(value: 60, unit: .kg)) == "60kg")
        #expect(WeightDisplay.weight(Weight(value: 62.5, unit: .lb)) == "62.5lb")
    }

    @Test func summaryReturnsEmptyStringForNoSets() {
        #expect(WeightDisplay.summary(of: []) == "")
    }

    @Test func summaryCollapsesRepsWhenWeightIsSame() {
        let exerciseId = UUID()
        let sets = [8, 8, 6].enumerated().map { index, reps in
            WorkoutSet(id: UUID(), exerciseId: exerciseId, exerciseIndex: 0, setIndex: index, weight: Weight(value: 60, unit: .kg), reps: reps)
        }

        #expect(WeightDisplay.summary(of: sets) == "60kg × 8, 8, 6")
    }

    @Test func summaryListsEachSetWhenWeightsDiffer() {
        let exerciseId = UUID()
        let sets = [
            WorkoutSet(id: UUID(), exerciseId: exerciseId, exerciseIndex: 0, setIndex: 0, weight: Weight(value: 60, unit: .kg), reps: 8),
            WorkoutSet(id: UUID(), exerciseId: exerciseId, exerciseIndex: 0, setIndex: 1, weight: Weight(value: 65, unit: .kg), reps: 6),
        ]

        #expect(WeightDisplay.summary(of: sets) == "60kg×8, 65kg×6")
    }
}
