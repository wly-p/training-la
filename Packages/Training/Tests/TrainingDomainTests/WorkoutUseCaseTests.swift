import Foundation
import SharedKernel
import Testing
import TrainingDomain

/// 補 WorkoutTests.swift 裡 WorkoutUseCaseTests 尚未覆蓋到的 use case：
/// SaveWorkoutProgress、LastPerformance，以及 FinishWorkout 的空白備註正規化。
struct WorkoutProgressUseCaseTests {
    @Test func saveWorkoutProgressPersistsToRepository() async throws {
        let repo = MockWorkoutRepository()
        let save = SaveWorkoutProgress(repository: repo)
        let workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 11))

        try await save(workout)

        #expect(try await repo.get(id: workout.id) == workout)
    }

    @Test func finishWorkoutNormalizesEmptyNoteToNil() async throws {
        let repo = MockWorkoutRepository()
        let workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 11))
        let finish = FinishWorkout(repository: repo)

        let finished = try await finish(workout, overallFeeling: nil, note: "")

        #expect(finished.note == nil)
    }

    @Test func lastPerformanceDelegatesToRepository() async throws {
        let repo = MockWorkoutRepository()
        let exerciseId = UUID()
        let sets = [WorkoutSet(id: UUID(), exerciseId: exerciseId, exerciseIndex: 0, setIndex: 0, weight: Weight(value: 60, unit: .kg), reps: 8)]
        await repo.stubLastPerformance(exerciseId: exerciseId, sets: sets)
        let lastPerformance = LastPerformance(repository: repo)

        #expect(try await lastPerformance(exerciseId: exerciseId, excludingWorkout: nil) == sets)
    }
}
