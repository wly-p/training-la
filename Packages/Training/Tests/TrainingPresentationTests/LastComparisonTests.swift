import Foundation
import SharedKernel
import Testing
import TrainingDomain

@testable import TrainingPresentation

/// 「和上次比」灰卡（14c）試算：找最近一場有做到主項的已完成場次，回日期／達標組數／主項增減。
struct LastComparisonTests {
    private let squatId = UUID()
    private let benchId = UUID()

    private func target(_ exId: UUID, index: Int, weight: Double?, reps: Int?) -> PlannedTargetSet {
        PlannedTargetSet(
            id: UUID(), exerciseId: exId, exerciseName: "x", exerciseIndex: index, setIndex: 0,
            targetWeight: weight.map { Weight(value: $0, unit: .kg) }, targetReps: reps, restSec: nil
        )
    }

    private func doneSet(_ exId: UUID, index: Int, setIndex: Int, weight: Double, reps: Int,
                        targetWeight: Double? = nil, targetReps: Int? = nil) -> WorkoutSet {
        WorkoutSet(
            id: UUID(), exerciseId: exId, exerciseIndex: index, setIndex: setIndex,
            measurement: .weightReps(weight: Weight(value: weight, unit: .kg), reps: reps), status: .done,
            targetMeasurement: targetWeight.map {
                .weightReps(weight: Weight(value: $0, unit: .kg), reps: targetReps ?? 0)
            }
        )
    }

    private func blueprint(mainWeight: Double?) -> PlannedWorkoutBlueprint {
        PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: "腿日", targets: [
            target(squatId, index: 0, weight: mainWeight, reps: 8)
        ])
    }

    @Test func noHistoryReturnsNil() {
        #expect(TrainingHomeViewModel.lastComparison(for: blueprint(mainWeight: 100), among: []) == nil)
    }

    @Test func skipsSessionsWithoutMainLift() {
        // 只有臥推的那場不算「上次的腿日」——沒有主項(深蹲)。
        let benchOnly = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 20),
                                sets: [doneSet(benchId, index: 0, setIndex: 0, weight: 60, reps: 8)])
        #expect(TrainingHomeViewModel.lastComparison(for: blueprint(mainWeight: 100), among: [benchOnly]) == nil)
    }

    @Test func computesAchievedCountsAndMainLiftDelta() {
        // 上次深蹲最重做到 95；達標 1/2（第一組達標、第二組沒達次數）。這次目標 100 → 主項 +5。
        let last = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 20), sets: [
            doneSet(squatId, index: 0, setIndex: 0, weight: 90, reps: 8, targetWeight: 90, targetReps: 8),
            doneSet(squatId, index: 0, setIndex: 1, weight: 95, reps: 5, targetWeight: 95, targetReps: 8),
        ])
        let c = TrainingHomeViewModel.lastComparison(for: blueprint(mainWeight: 100), among: [last])
        #expect(c?.date == DayDate(year: 2026, month: 7, day: 20))
        #expect(c?.achievedSets == 1)
        #expect(c?.totalSets == 2)
        #expect(c?.mainLiftDeltaKg == 5)
    }

    @Test func picksMostRecentMatchingSession() {
        let older = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 13),
                            sets: [doneSet(squatId, index: 0, setIndex: 0, weight: 80, reps: 8)])
        let newer = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 20),
                            sets: [doneSet(squatId, index: 0, setIndex: 0, weight: 90, reps: 8)])
        // finished 慣例最近在前。
        let c = TrainingHomeViewModel.lastComparison(for: blueprint(mainWeight: 90), among: [newer, older])
        #expect(c?.date == DayDate(year: 2026, month: 7, day: 20))
        #expect(c?.mainLiftDeltaKg == 0)   // 90 − 90
    }

    @Test func nilDeltaWhenThisTargetUnknown() {
        let last = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 20),
                           sets: [doneSet(squatId, index: 0, setIndex: 0, weight: 90, reps: 8)])
        let c = TrainingHomeViewModel.lastComparison(for: blueprint(mainWeight: nil), among: [last])
        #expect(c != nil)
        #expect(c?.mainLiftDeltaKg == nil)
    }
}
