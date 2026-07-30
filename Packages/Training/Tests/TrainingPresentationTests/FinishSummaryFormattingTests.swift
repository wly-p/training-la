import Foundation
import SharedKernel
import Testing
import TrainingDomain

@testable import TrainingPresentation

private let exerciseId = UUID()

private func set(
    weight: Double, reps: Int, status: WorkoutSetStatus = .done,
    targetWeight: Double? = nil, targetReps: Int? = nil, index: Int = 0, setIndex: Int = 0
) -> WorkoutSet {
    WorkoutSet(
        id: UUID(), exerciseId: exerciseId, exerciseIndex: index, setIndex: setIndex,
        weight: Weight(value: weight, unit: .kg), reps: reps, status: status,
        targetWeight: targetWeight.map { Weight(value: $0, unit: .kg) }, targetReps: targetReps
    )
}

struct FinishSummaryFormattingTests {
    @Test func achievedRequiresBothWeightAndRepsAtLeastTarget() {
        #expect(FinishSummaryFormatting.achieved(set(weight: 80, reps: 8, targetWeight: 80, targetReps: 8)) == true)
        #expect(FinishSummaryFormatting.achieved(set(weight: 80, reps: 8, targetWeight: 80, targetReps: 10)) == false)
        #expect(FinishSummaryFormatting.achieved(set(weight: 75, reps: 8, targetWeight: 80, targetReps: 8)) == false)
        #expect(FinishSummaryFormatting.achieved(set(weight: 85, reps: 10, targetWeight: 80, targetReps: 8)) == true)
    }

    @Test func achievedIsNilWithoutTargetSnapshotOrWhenSkipped() {
        #expect(FinishSummaryFormatting.achieved(set(weight: 80, reps: 8)) == nil)   // 沒有目標快照（自由加練）
        #expect(FinishSummaryFormatting.achieved(set(weight: 80, reps: 8, status: .skipped, targetWeight: 80, targetReps: 8)) == nil)
    }

    @Test func achievedSetCountExcludesUnjudgedSets() {
        let sets = [
            set(weight: 80, reps: 8, targetWeight: 80, targetReps: 8),     // 達標
            set(weight: 70, reps: 8, targetWeight: 80, targetReps: 8),     // 沒達標
            set(weight: 20, reps: 8),                                      // 自由加練，不列入分母
            set(weight: 80, reps: 8, status: .skipped, targetWeight: 80, targetReps: 8),   // 跳過，不列入
        ]

        let (achieved, total) = FinishSummaryFormatting.achievedSetCount(sets)

        #expect(achieved == 1)
        #expect(total == 2)
    }

    @Test func totalVolumeOnlyCountsDoneSets() {
        let sets = [
            set(weight: 80, reps: 8),                       // 80×8=640
            set(weight: 60, reps: 10, status: .skipped),    // 跳過不算
        ]

        #expect(FinishSummaryFormatting.totalVolume(sets) == 640)
    }

    @Test func targetVolumeOnlyCountsSetsWithTargetSnapshot() {
        let sets = [
            set(weight: 80, reps: 8, targetWeight: 75, targetReps: 8),   // 目標量 75×8=600
            set(weight: 20, reps: 8),                                     // 沒目標，不計入
        ]

        #expect(FinishSummaryFormatting.targetVolume(sets) == 600)
    }

    private func blocks(_ sets: [WorkoutSet]) -> [ExerciseBlock] {
        Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 24), sets: sets).blocks
    }

    @Test func exerciseSummariesReportsWeightRangeAndAchievement() {
        let benchId = UUID()
        let sets = [
            WorkoutSet(id: UUID(), exerciseId: benchId, exerciseIndex: 0, setIndex: 0,
                      weight: Weight(value: 60, unit: .kg), reps: 8, status: .done,
                      targetWeight: Weight(value: 60, unit: .kg), targetReps: 8),
            WorkoutSet(id: UUID(), exerciseId: benchId, exerciseIndex: 0, setIndex: 1,
                      weight: Weight(value: 80, unit: .kg), reps: 8, status: .done,
                      targetWeight: Weight(value: 80, unit: .kg), targetReps: 8),
        ]

        let summaries = FinishSummaryFormatting.exerciseSummaries(blocks(sets)) { _ in "臥推" }

        #expect(summaries.count == 1)
        #expect(summaries[0].name == "臥推")
        #expect(summaries[0].setCount == 2)
        #expect(summaries[0].weightRange == "60→80")
        #expect(summaries[0].allAchieved == true)
    }

    @Test func exerciseSummaryAllAchievedIsNilWhenNothingJudged() {
        let summaries = FinishSummaryFormatting.exerciseSummaries(blocks([set(weight: 20, reps: 8)])) { _ in "自由加練" }

        #expect(summaries[0].allAchieved == nil)
    }

    @Test func exerciseSummaryAllAchievedIsFalseWhenAnySetMisses() {
        let sets = [
            set(weight: 80, reps: 8, targetWeight: 80, targetReps: 8, setIndex: 0),
            set(weight: 60, reps: 8, targetWeight: 80, targetReps: 8, setIndex: 1),
        ]

        let summaries = FinishSummaryFormatting.exerciseSummaries(blocks(sets)) { _ in "臥推" }

        #expect(summaries[0].allAchieved == false)
    }
}
