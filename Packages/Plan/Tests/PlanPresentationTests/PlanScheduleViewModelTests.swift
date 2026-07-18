import Foundation
import PlanDomain
import SharedKernel
import Testing

@testable import PlanPresentation

private actor MockScheduleRepo: PlanWorkoutRepository {
    var storage: [UUID: PlanWorkout] = [:]

    func seed(_ items: [PlanWorkout]) { for item in items { storage[item.id] = item } }
    func all() async throws -> [PlanWorkout] { storage.values.sorted { $0.orderIndex < $1.orderIndex } }
    func get(id: UUID) async throws -> PlanWorkout? { storage[id] }
    func save(_ planWorkout: PlanWorkout) async throws { storage[planWorkout.id] = planWorkout }
    func delete(id: UUID) async throws {
        guard storage.removeValue(forKey: id) != nil else {
            throw PlanWorkoutRepositoryError.notFound(id: id)
        }
    }
    func onDate(_ day: DayDate) async throws -> [PlanWorkout] { storage.values.filter { $0.date == day } }
    func cycle() async throws -> [PlanWorkout] { storage.values.filter { $0.date == nil } }
    func usesExercise(_ exerciseId: UUID) async throws -> Bool { false }
}

private struct MockCatalog: PlanExerciseCatalog {
    let items: [PlanCatalogExercise]
    func exercises() async throws -> [PlanCatalogExercise] { items }
}

@MainActor
private func makeViewModel(repo: MockScheduleRepo, catalog: [PlanCatalogExercise] = []) -> PlanScheduleViewModel {
    PlanScheduleViewModel(
        listPlanWorkouts: ListPlanWorkouts(repository: repo),
        createPlanWorkout: CreatePlanWorkout(repository: repo),
        updatePlanWorkout: UpdatePlanWorkout(repository: repo),
        deletePlanWorkout: DeletePlanWorkout(repository: repo),
        exerciseCatalog: MockCatalog(items: catalog)
    )
}

@MainActor
struct PlanScheduleViewModelTests {
    private func draft(_ setCount: Int = 2) -> ExerciseTargetDraft {
        ExerciseTargetDraft(exerciseId: UUID(), setCount: setCount, targetWeight: Weight(value: 60, unit: .kg), targetReps: 8)
    }

    @Test func loadPopulatesPlanWorkoutsAndCatalog() async {
        let repo = MockScheduleRepo()
        let exerciseId = UUID()
        await repo.seed([PlanWorkout(id: UUID(), name: "推日", date: nil, orderIndex: 0)])
        let vm = makeViewModel(repo: repo, catalog: [PlanCatalogExercise(id: exerciseId, name: "臥推", muscleGroup: .chest)])

        await vm.load()

        #expect(vm.planWorkouts.count == 1)
        #expect(vm.name(for: exerciseId) == "臥推")
        #expect(vm.errorMessage == nil)
    }

    @Test func nameFallsBackToDefaultForUnknownExercise() async {
        let vm = makeViewModel(repo: MockScheduleRepo())
        #expect(vm.name(for: UUID()) == "動作")
    }

    @Test func datedWorkoutsExcludesCycleAndSortsByDateThenOrder() async {
        let repo = MockScheduleRepo()
        let day1 = DayDate(year: 2026, month: 7, day: 10)
        let day2 = DayDate(year: 2026, month: 7, day: 11)
        await repo.seed([
            PlanWorkout(id: UUID(), name: "循環", date: nil, orderIndex: 0),
            PlanWorkout(id: UUID(), name: "晚一點", date: day2, orderIndex: 0),
            PlanWorkout(id: UUID(), name: "早一點", date: day1, orderIndex: 0),
        ])
        let vm = makeViewModel(repo: repo)
        await vm.load()

        #expect(vm.datedWorkouts.map(\.name) == ["早一點", "晚一點"])
    }

    @Test func cycleWorkoutsExcludesDatedAndSortsByOrderIndex() async {
        let repo = MockScheduleRepo()
        await repo.seed([
            PlanWorkout(id: UUID(), name: "有日期", date: DayDate(year: 2026, month: 7, day: 10), orderIndex: 0),
            PlanWorkout(id: UUID(), name: "拉", date: nil, orderIndex: 1),
            PlanWorkout(id: UUID(), name: "推", date: nil, orderIndex: 0),
        ])
        let vm = makeViewModel(repo: repo)
        await vm.load()

        #expect(vm.cycleWorkouts.map(\.name) == ["推", "拉"])
    }

    @Test func createAddsPlanWorkoutAndReloads() async {
        let repo = MockScheduleRepo()
        let vm = makeViewModel(repo: repo)

        await vm.create(name: "推日", date: nil, drafts: [draft()])

        #expect(vm.planWorkouts.count == 1)
        #expect(vm.errorMessage == nil)
    }

    @Test func createWithEmptyDraftsSetsErrorMessage() async {
        let vm = makeViewModel(repo: MockScheduleRepo())

        await vm.create(name: "空", date: nil, drafts: [])

        #expect(vm.errorMessage?.key == "plan.error.needExercise")
        #expect(vm.planWorkouts.isEmpty)
    }

    @Test func updateEditsExistingPlanWorkout() async {
        let repo = MockScheduleRepo()
        let existing = PlanWorkout(id: UUID(), name: "推日", date: nil, orderIndex: 0)
        await repo.seed([existing])
        let vm = makeViewModel(repo: repo)
        await vm.load()

        await vm.update(id: existing.id, name: "拉日", date: nil, drafts: [draft(3)])

        #expect(vm.planWorkouts.first?.name == "拉日")
    }

    @Test func deleteRemovesPlanWorkout() async {
        let repo = MockScheduleRepo()
        let existing = PlanWorkout(id: UUID(), name: "推日", date: nil, orderIndex: 0)
        await repo.seed([existing])
        let vm = makeViewModel(repo: repo)
        await vm.load()

        await vm.delete(id: existing.id)

        #expect(vm.planWorkouts.isEmpty)
    }

    @Test func dismissErrorClearsErrorMessage() async {
        let vm = makeViewModel(repo: MockScheduleRepo())
        await vm.create(name: "空", date: nil, drafts: [])
        #expect(vm.errorMessage != nil)

        vm.dismissError()

        #expect(vm.errorMessage == nil)
    }
}
