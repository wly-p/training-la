import Foundation
import SharedKernel
import SwiftData
import Testing
import TrainingDomain

@testable import TrainingData

struct SwiftDataWorkoutRepositoryTests {
    private func makeRepository() throws -> any WorkoutRepository {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Schema(TrainingDataFactory.models),
            configurations: config
        )
        return TrainingDataFactory.makeWorkoutRepository(container: container)
    }

    private let kg60 = Weight(value: 60, unit: .kg)
    private let today = DayDate(year: 2026, month: 7, day: 9)

    private func workoutWithSets(_ exerciseId: UUID, reps: [Int], day: DayDate? = nil) -> Workout {
        var workout = Workout(id: UUID(), day: day ?? today, startedAt: Date())
        for count in reps {
            workout.appendSet(exerciseId: exerciseId, weight: kg60, reps: count)
        }
        return workout
    }

    @Test func saveThenGetRoundTripsWholeTree() async throws {
        let repo = try makeRepository()
        let workout = workoutWithSets(UUID(), reps: [8, 8, 6])

        try await repo.save(workout)
        let fetched = try await repo.get(id: workout.id)

        #expect(fetched == workout)
    }

    @Test func saveReplacesAggregate() async throws {
        let repo = try makeRepository()
        var workout = workoutWithSets(UUID(), reps: [8, 8])
        try await repo.save(workout)

        workout.note = "改了"
        workout.sets.removeLast() // 整包取代：組數可以變少
        try await repo.save(workout)

        let fetched = try await repo.get(id: workout.id)
        #expect(fetched?.note == "改了")
        #expect(fetched?.sets.count == 1)
    }

    @Test func activeWorkoutReturnsUnfinishedOnly() async throws {
        let repo = try makeRepository()
        var finished = workoutWithSets(UUID(), reps: [8])
        finished.endedAt = Date()
        try await repo.save(finished)
        #expect(try await repo.activeWorkout() == nil)

        let active = workoutWithSets(UUID(), reps: [5])
        try await repo.save(active)
        #expect(try await repo.activeWorkout()?.id == active.id)
    }

    @Test func lastPerformanceFindsMostRecentFinishedSets() async throws {
        let repo = try makeRepository()
        let benchPress = UUID()

        var older = workoutWithSets(benchPress, reps: [10, 10], day: DayDate(year: 2026, month: 7, day: 1))
        older.endedAt = Date()
        var newer = workoutWithSets(benchPress, reps: [8, 8, 6], day: DayDate(year: 2026, month: 7, day: 7))
        newer.endedAt = Date()
        let inProgress = workoutWithSets(benchPress, reps: [5]) // 未完成，要被排除
        try await repo.save(older)
        try await repo.save(newer)
        try await repo.save(inProgress)

        let sets = try await repo.lastPerformance(exerciseId: benchPress, excludingWorkout: inProgress.id)

        #expect(sets.map(\.reps) == [8, 8, 6])
    }

    @Test func lastPerformanceEmptyWhenNoHistory() async throws {
        let repo = try makeRepository()
        let sets = try await repo.lastPerformance(exerciseId: UUID(), excludingWorkout: nil)
        #expect(sets.isEmpty)
    }

    @Test func usesExerciseReflectsRecordedSets() async throws {
        let repo = try makeRepository()
        let benchPress = UUID()
        let squat = UUID()
        try await repo.save(workoutWithSets(benchPress, reps: [8, 8]))

        #expect(try await repo.usesExercise(benchPress) == true)
        #expect(try await repo.usesExercise(squat) == false)
    }

    @Test func deleteRemovesWorkout() async throws {
        let repo = try makeRepository()
        let workout = workoutWithSets(UUID(), reps: [8])
        try await repo.save(workout)

        try await repo.delete(id: workout.id)

        #expect(try await repo.get(id: workout.id) == nil)
    }
}
