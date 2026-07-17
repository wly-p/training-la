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

    @Test func loadPopulatesWorkoutsAndSelectsFirstExercise() async throws {
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
        #expect(vm.selectedExerciseId == squatId)
        // 選定第一個動作後 sessions 應載入
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.sessions.count == 1)
    }

    @Test func changingExerciseReloadsSessions() async throws {
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
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.sessions.count == 1) // 深蹲

        vm.selectedExerciseId = benchId
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.sessions.count == 2) // 臥推
    }
}
