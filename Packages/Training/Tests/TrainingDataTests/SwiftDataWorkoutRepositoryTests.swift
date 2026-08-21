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

    // MARK: - exerciseHistory
    //
    // 這支原本完全沒有測試，而它的查詢在效能修正時被整個重寫
    // （從「撈全部場次再過濾」改成「對 WorkoutSetModel 下 exerciseId predicate」）。
    // 以下把它的四個不變式釘住。

    @Test func exerciseHistoryReturnsOnlyThatExercisesSets() async throws {
        let repo = try makeRepository()
        let squat = UUID(), bench = UUID()
        var workout = Workout(id: UUID(), day: today, startedAt: Date(), endedAt: Date())
        workout.appendSet(exerciseId: squat, weight: kg60, reps: 5)
        workout.appendSet(exerciseId: bench, weight: kg60, reps: 8)
        workout.appendSet(exerciseId: squat, weight: kg60, reps: 4)
        try await repo.save(workout)

        let history = try await repo.exerciseHistory(exerciseId: squat)

        #expect(history.count == 2)
        #expect(history.allSatisfy { $0.set.exerciseId == squat })
        #expect(history.allSatisfy { $0.workoutId == workout.id })
        #expect(history.allSatisfy { $0.day == today })
    }

    /// 進行中的那場不該進歷史——原本靠 `endedAt != nil` 的 predicate 擋，
    /// 改寫後改成走關聯回 workout 判斷，這條要重新釘。
    @Test func exerciseHistoryExcludesUnfinishedWorkouts() async throws {
        let repo = try makeRepository()
        let squat = UUID()
        var finished = Workout(id: UUID(), day: today, startedAt: Date(), endedAt: Date())
        finished.appendSet(exerciseId: squat, weight: kg60, reps: 5)
        var inProgress = Workout(id: UUID(), day: today, startedAt: Date())   // endedAt = nil
        inProgress.appendSet(exerciseId: squat, weight: kg60, reps: 99)
        try await repo.save(finished)
        try await repo.save(inProgress)

        let history = try await repo.exerciseHistory(exerciseId: squat)

        #expect(history.count == 1)
        #expect(history.first?.set.reps == 5)
    }

    @Test func exerciseHistoryIsNewestFirst() async throws {
        let repo = try makeRepository()
        let squat = UUID()
        let older = DayDate(year: 2026, month: 7, day: 1)
        let newer = DayDate(year: 2026, month: 7, day: 20)
        for (day, reps) in [(older, 5), (newer, 8)] {
            var w = Workout(id: UUID(), day: day, startedAt: Date(), endedAt: Date())
            w.appendSet(exerciseId: squat, weight: kg60, reps: reps)
            try await repo.save(w)
        }

        let history = try await repo.exerciseHistory(exerciseId: squat)

        #expect(history.map(\.day) == [newer, older])
    }

    /// 同一場之內要維持 (exerciseIndex, setIndex) 的自然順序，輸出才穩定。
    @Test func exerciseHistoryKeepsSetOrderWithinASession() async throws {
        let repo = try makeRepository()
        let squat = UUID()
        var workout = Workout(id: UUID(), day: today, startedAt: Date(), endedAt: Date())
        for reps in [10, 8, 6] { workout.appendSet(exerciseId: squat, weight: kg60, reps: reps) }
        try await repo.save(workout)

        let history = try await repo.exerciseHistory(exerciseId: squat)

        #expect(history.map(\.set.setIndex) == [0, 1, 2])
        #expect(history.map(\.set.reps) == [10, 8, 6])
    }

    @Test func exerciseHistoryIsEmptyForUnknownExercise() async throws {
        let repo = try makeRepository()
        var workout = Workout(id: UUID(), day: today, startedAt: Date(), endedAt: Date())
        workout.appendSet(exerciseId: UUID(), weight: kg60, reps: 5)
        try await repo.save(workout)

        #expect(try await repo.exerciseHistory(exerciseId: UUID()).isEmpty)
    }

    // MARK: - finishedWorkouts 的上限

    @Test func finishedWorkoutsWithoutLimitReturnsAll() async throws {
        let repo = try makeRepository()
        for offset in 0..<5 {
            try await repo.save(Workout(
                id: UUID(), day: today.adding(days: -offset),
                startedAt: Date(), endedAt: Date()
            ))
        }

        #expect(try await repo.finishedWorkouts().count == 5)
    }

    /// 上限要取**最新**的那幾場，不是任意幾場——訓練首頁的「本週」與「最近練過」都靠這個。
    @Test func finishedWorkoutsWithLimitTakesTheNewest() async throws {
        let repo = try makeRepository()
        for offset in 0..<5 {
            try await repo.save(Workout(
                id: UUID(), day: today.adding(days: -offset),
                startedAt: Date(), endedAt: Date()
            ))
        }

        let recent = try await repo.finishedWorkouts(limit: 2)

        #expect(recent.count == 2)
        #expect(recent.map(\.day) == [today, today.adding(days: -1)])
    }

    @Test func deleteRemovesWorkout() async throws {
        let repo = try makeRepository()
        let workout = workoutWithSets(UUID(), reps: [8])
        try await repo.save(workout)

        try await repo.delete(id: workout.id)

        #expect(try await repo.get(id: workout.id) == nil)
    }
}
