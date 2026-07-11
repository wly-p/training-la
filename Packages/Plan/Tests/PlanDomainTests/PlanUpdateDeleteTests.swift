import Foundation
import PlanDomain
import SharedKernel
import Testing

struct ListPlanWorkoutsTests {
    @Test func listReturnsAllFromRepository() async throws {
        let repo = MockPlanWorkoutRepository()
        let plan = PlanWorkout(id: UUID(), name: "推日", date: nil, orderIndex: 0)
        await repo.seed([plan])

        let workouts = try await ListPlanWorkouts(repository: repo)()

        #expect(workouts.map(\.id) == [plan.id])
    }
}

struct UpdatePlanWorkoutTests {
    private func draft(_ setCount: Int = 2) -> ExerciseTargetDraft {
        ExerciseTargetDraft(exerciseId: UUID(), setCount: setCount, targetWeight: Weight(value: 60, unit: .kg), targetReps: 8)
    }

    @Test func updateReplacesNameDateAndSetsButKeepsOrderIndexAndStatus() async throws {
        let repo = MockPlanWorkoutRepository()
        let original = PlanWorkout(id: UUID(), name: "推日", date: nil, status: .done, orderIndex: 3)
        await repo.seed([original])
        let update = UpdatePlanWorkout(repository: repo)

        let newDate = DayDate(year: 2026, month: 7, day: 12)
        let updated = try await update(id: original.id, name: "拉日", date: newDate, drafts: [draft(3)])

        #expect(updated.name == "拉日")
        #expect(updated.date == newDate)
        #expect(updated.orderIndex == 3)
        #expect(updated.status == .done)
        #expect(updated.sets.count == 3)
    }

    @Test func updateRejectsEmptyDrafts() async throws {
        let repo = MockPlanWorkoutRepository()
        let original = PlanWorkout(id: UUID(), name: "推日", date: nil, orderIndex: 0)
        await repo.seed([original])
        let update = UpdatePlanWorkout(repository: repo)

        await #expect(throws: PlanWorkoutValidationError.empty) {
            try await update(id: original.id, name: "推日", date: nil, drafts: [])
        }
    }

    @Test func updateMissingPlanWorkoutThrowsNotFound() async throws {
        let repo = MockPlanWorkoutRepository()
        let update = UpdatePlanWorkout(repository: repo)
        let ghost = UUID()

        await #expect(throws: PlanWorkoutRepositoryError.notFound(id: ghost)) {
            try await update(id: ghost, name: "推日", date: nil, drafts: [draft()])
        }
    }
}

struct DeletePlanWorkoutTests {
    @Test func deleteRemovesFromRepository() async throws {
        let repo = MockPlanWorkoutRepository()
        let plan = PlanWorkout(id: UUID(), name: "推日", date: nil, orderIndex: 0)
        await repo.seed([plan])
        let delete = DeletePlanWorkout(repository: repo)

        try await delete(id: plan.id)

        #expect(try await repo.get(id: plan.id) == nil)
    }
}
