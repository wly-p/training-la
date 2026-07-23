import Foundation
import PlanDomain
import SharedKernel
import Testing

@testable import PlanPresentation

private let day1 = DayDate(year: 2026, month: 7, day: 10)
private let day2 = DayDate(year: 2026, month: 7, day: 11)

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
    func usesExercise(_ exerciseId: UUID) async throws -> Bool { false }
}

private struct MockCatalog: PlanExerciseCatalog {
    let items: [PlanCatalogExercise]
    func exercises() async throws -> [PlanCatalogExercise] { items }
}

private actor MockTemplateRepo: WorkoutTemplateRepository {
    var storage: [UUID: WorkoutTemplate] = [:]
    func seed(_ items: [WorkoutTemplate]) { for i in items { storage[i.id] = i } }
    func all() async throws -> [WorkoutTemplate] { storage.values.sorted { $0.orderIndex < $1.orderIndex } }
    func get(id: UUID) async throws -> WorkoutTemplate? { storage[id] }
    func save(_ t: WorkoutTemplate) async throws { storage[t.id] = t }
    func delete(id: UUID) async throws { storage[id] = nil }
    func usesExercise(_ exerciseId: UUID) async throws -> Bool { false }
}

@MainActor
private func makeViewModel(
    repo: MockScheduleRepo,
    templateRepo: MockTemplateRepo = MockTemplateRepo(),
    catalog: [PlanCatalogExercise] = []
) -> PlanScheduleViewModel {
    PlanScheduleViewModel(
        listPlanWorkouts: ListPlanWorkouts(repository: repo),
        createPlanWorkout: CreatePlanWorkout(repository: repo),
        updatePlanWorkout: UpdatePlanWorkout(repository: repo),
        deletePlanWorkout: DeletePlanWorkout(repository: repo),
        listTemplates: ListTemplates(repository: templateRepo),
        instantiateTemplate: InstantiateTemplate(templateRepository: templateRepo, planRepository: repo),
        exerciseCatalog: MockCatalog(items: catalog),
        today: { day1 }
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
        await repo.seed([PlanWorkout(id: UUID(), name: "推日", date: day1, orderIndex: 0)])
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

    @Test func workoutsMarksReflectDatesAndStatus() async {
        let repo = MockScheduleRepo()
        await repo.seed([
            PlanWorkout(id: UUID(), name: "d1a", date: day1, status: .done, orderIndex: 0),
            PlanWorkout(id: UUID(), name: "d1b", date: day1, status: .notStarted, orderIndex: 1),
            PlanWorkout(id: UUID(), name: "d2", date: day2, status: .done, orderIndex: 0),
        ])
        let vm = makeViewModel(repo: repo)
        await vm.load()

        #expect(vm.workouts(on: day1).map(\.name) == ["d1a", "d1b"])
        #expect(vm.markedDates == [day1, day2])
        #expect(vm.mark(on: day1) == .scheduled)   // 有一個未完成
        #expect(vm.mark(on: day2) == .done)         // 全部完成
        #expect(vm.mark(on: DayDate(year: 2026, month: 7, day: 12)) == nil)
    }

    @Test func addFromTemplateCreatesDatedPlanFromSnapshot() async {
        let repo = MockScheduleRepo()
        let trepo = MockTemplateRepo()
        let tpl = WorkoutTemplate(
            id: UUID(), name: "推", source: .user, orderIndex: 0,
            sets: [PlanSet(id: UUID(), exerciseId: UUID(), exerciseIndex: 0, setIndex: 0, targetWeight: nil, targetReps: nil)],
            createdAt: Date(), updatedAt: Date()
        )
        await trepo.seed([tpl])
        let vm = makeViewModel(repo: repo, templateRepo: trepo)
        await vm.load()

        await vm.addFromTemplate(templateId: tpl.id, on: day2)

        #expect(vm.workouts(on: day2).count == 1)
        #expect(vm.workouts(on: day2).first?.templateId == tpl.id)
    }

    @Test func createAddsPlanWorkoutAndReloads() async {
        let repo = MockScheduleRepo()
        let vm = makeViewModel(repo: repo)

        await vm.create(name: "推日", date: day1, drafts: [draft()])

        #expect(vm.planWorkouts.count == 1)
        #expect(vm.errorMessage == nil)
    }

    @Test func createWithEmptyDraftsSetsErrorMessage() async {
        let vm = makeViewModel(repo: MockScheduleRepo())

        await vm.create(name: "空", date: day1, drafts: [])

        #expect(vm.errorMessage?.key == "plan.error.needExercise")
        #expect(vm.planWorkouts.isEmpty)
    }

    @Test func updateEditsExistingPlanWorkout() async {
        let repo = MockScheduleRepo()
        let existing = PlanWorkout(id: UUID(), name: "推日", date: day1, orderIndex: 0)
        await repo.seed([existing])
        let vm = makeViewModel(repo: repo)
        await vm.load()

        await vm.update(id: existing.id, name: "拉日", date: day1, drafts: [draft(3)])

        #expect(vm.planWorkouts.first?.name == "拉日")
    }

    @Test func deleteRemovesPlanWorkout() async {
        let repo = MockScheduleRepo()
        let existing = PlanWorkout(id: UUID(), name: "推日", date: day1, orderIndex: 0)
        await repo.seed([existing])
        let vm = makeViewModel(repo: repo)
        await vm.load()

        await vm.delete(id: existing.id)

        #expect(vm.planWorkouts.isEmpty)
    }

    @Test func dismissErrorClearsErrorMessage() async {
        let vm = makeViewModel(repo: MockScheduleRepo())
        await vm.create(name: "空", date: day1, drafts: [])
        #expect(vm.errorMessage != nil)

        vm.dismissError()

        #expect(vm.errorMessage == nil)
    }
}
