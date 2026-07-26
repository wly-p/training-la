import Foundation
import HistoryDomain
import SharedKernel
import Testing

@testable import HistoryPresentation

private actor StubReading: WorkoutHistoryReading {
    var workoutsResult: [HistoryWorkoutSummary] = []
    var optionsResult: [HistoryExerciseOption] = []
    var sessionsByExercise: [UUID: [HistoryExerciseSession]] = [:]

    func setUp(
        workouts: [HistoryWorkoutSummary],
        options: [HistoryExerciseOption],
        sessions: [UUID: [HistoryExerciseSession]]
    ) {
        workoutsResult = workouts
        optionsResult = options
        sessionsByExercise = sessions
    }

    func workouts() async throws -> [HistoryWorkoutSummary] { workoutsResult }
    func workoutDetail(id: UUID) async throws -> HistoryWorkoutDetail? { nil }
    func exercisesWithHistory() async throws -> [HistoryExerciseOption] { optionsResult }
    func sessions(exerciseId: UUID) async throws -> [HistoryExerciseSession] {
        sessionsByExercise[exerciseId] ?? []
    }
}

/// 不做事的編輯 port（這些測試只驗讀取流程）。
private struct NoopEditing: WorkoutHistoryEditing {
    func deleteWorkout(id: UUID) async throws {}
    func updateSets(workoutId: UUID, edits: [HistorySetEdit]) async throws {}
}

@MainActor
struct HistoryViewModelTests {
    private func line(reps: Int) -> HistorySetLine {
        HistorySetLine(id: UUID(), setIndex: 0, weight: Weight(value: 60, unit: .kg),
                       reps: reps, status: .done, targetWeight: nil, targetReps: nil)
    }

    @Test func loadPopulatesWorkoutsAndExerciseOptions() async throws {
        let squatId = UUID()
        let stub = StubReading()
        let day = DayDate(year: 2026, month: 7, day: 9)
        await stub.setUp(
            workouts: [HistoryWorkoutSummary(id: UUID(), day: day, exerciseCount: 1,
                                             totalSets: 3, overallFeeling: 4, durationMinutes: 40)],
            options: [HistoryExerciseOption(id: squatId, name: "深蹲", muscleGroup: .legs)],
            sessions: [squatId: [HistoryExerciseSession(id: UUID(), day: day, sets: [line(reps: 8)])]]
        )
        let vm = HistoryViewModel(reading: stub, editing: NoopEditing())

        await vm.load()

        #expect(vm.workouts.count == 1)
        #expect(vm.exerciseOptions.map(\.id) == [squatId])
        // 「依動作」清單頁本身不查 sessions，點進單一動作頁才查（見 ExerciseHistoryView）。
        let sessions = await vm.sessions(for: squatId)
        #expect(sessions.count == 1)
    }

    @Test func sessionsForExerciseQueriesIndependently() async throws {
        let squatId = UUID()
        let benchId = UUID()
        let stub = StubReading()
        let day = DayDate(year: 2026, month: 7, day: 9)
        await stub.setUp(
            workouts: [],
            options: [
                HistoryExerciseOption(id: squatId, name: "深蹲", muscleGroup: .legs),
                HistoryExerciseOption(id: benchId, name: "臥推", muscleGroup: .chest),
            ],
            sessions: [
                squatId: [HistoryExerciseSession(id: UUID(), day: day, sets: [line(reps: 5)])],
                benchId: [
                    HistoryExerciseSession(id: UUID(), day: day, sets: [line(reps: 8)]),
                    HistoryExerciseSession(id: UUID(), day: day, sets: [line(reps: 6)]),
                ],
            ]
        )
        let vm = HistoryViewModel(reading: stub, editing: NoopEditing())
        await vm.load()

        #expect(await vm.sessions(for: squatId).count == 1)
        #expect(await vm.sessions(for: benchId).count == 2)
    }
}
