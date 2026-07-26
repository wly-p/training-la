import Foundation
import PlanDomain
import SharedKernel
import Testing

actor MockWorkoutTemplateRepository: WorkoutTemplateRepository {
    private(set) var storage: [UUID: WorkoutTemplate] = [:]

    func seed(_ items: [WorkoutTemplate]) { for item in items { storage[item.id] = item } }

    func all() async throws -> [WorkoutTemplate] {
        storage.values.sorted { $0.orderIndex < $1.orderIndex }
    }
    func get(id: UUID) async throws -> WorkoutTemplate? { storage[id] }
    func save(_ template: WorkoutTemplate) async throws { storage[template.id] = template }
    func delete(id: UUID) async throws {
        guard storage.removeValue(forKey: id) != nil else {
            throw WorkoutTemplateRepositoryError.notFound(id: id)
        }
    }
    func usesExercise(_ exerciseId: UUID) async throws -> Bool {
        storage.values.contains { $0.sets.contains { $0.exerciseId == exerciseId } }
    }
}

/// 逐組編輯後直接建構 `[PlanSet]`（新版範本編輯器不再經過 `ExerciseTargetDraft`）。
private func uniformBlock(exerciseIndex: Int, setCount: Int = 3, weight: Double = 100, reps: Int = 5) -> [PlanSet] {
    (0..<setCount).map { setIndex in
        PlanSet(
            id: UUID(), exerciseId: UUID(), exerciseIndex: exerciseIndex, setIndex: setIndex,
            targetWeight: .absolute(Weight(value: weight, unit: .kg)), targetReps: reps
        )
    }
}

struct CreateTemplateTests {
    @Test func createExpandsDraftsAndDefaultsToUserSource() async throws {
        let repo = MockWorkoutTemplateRepository()
        let create = CreateTemplate(repository: repo)

        let template = try await create(name: "推日範本", sets: uniformBlock(exerciseIndex: 0, setCount: 3) + uniformBlock(exerciseIndex: 1, setCount: 2))

        #expect(template.name == "推日範本")
        #expect(template.source == .user)
        #expect(template.sets.count == 5)
        #expect(template.blocks.count == 2)
    }

    @Test func createTrimsAndRejectsEmptyName() async throws {
        let create = CreateTemplate(repository: MockWorkoutTemplateRepository())
        await #expect(throws: PlanWorkoutValidationError.emptyName) {
            try await create(name: "   ", sets: uniformBlock(exerciseIndex: 0))
        }
    }

    @Test func createRejectsEmptyDrafts() async throws {
        let create = CreateTemplate(repository: MockWorkoutTemplateRepository())
        await #expect(throws: PlanWorkoutValidationError.empty) {
            try await create(name: "空範本", sets: [])
        }
    }

    @Test func createAssignsIncreasingOrderIndex() async throws {
        let repo = MockWorkoutTemplateRepository()
        let create = CreateTemplate(repository: repo)

        let first = try await create(name: "A", sets: uniformBlock(exerciseIndex: 0))
        let second = try await create(name: "B", sets: uniformBlock(exerciseIndex: 0))

        #expect(first.orderIndex == 0)
        #expect(second.orderIndex == 1)
    }
}

struct UpdateTemplateTests {
    @Test func updateReplacesNameAndSetsButKeepsSourceAndOrderIndex() async throws {
        let repo = MockWorkoutTemplateRepository()
        let original = WorkoutTemplate(id: UUID(), name: "舊", source: .official, orderIndex: 3,
                                       sets: [], createdAt: .init(timeIntervalSince1970: 0), updatedAt: .init(timeIntervalSince1970: 0))
        await repo.seed([original])
        let update = UpdateTemplate(repository: repo)

        let updated = try await update(
            id: original.id, name: "新",
            sets: uniformBlock(exerciseIndex: 0, setCount: 2, weight: 60, reps: 8) + uniformBlock(exerciseIndex: 1, setCount: 2, weight: 60, reps: 8)
        )

        #expect(updated.name == "新")
        #expect(updated.source == .official)
        #expect(updated.orderIndex == 3)
        #expect(updated.sets.count == 4)   // 2 動作 × 2 組
        #expect(updated.blocks.count == 2)
    }

    @Test func updateMissingThrowsNotFound() async throws {
        let repo = MockWorkoutTemplateRepository()
        let ghost = UUID()
        await #expect(throws: WorkoutTemplateRepositoryError.notFound(id: ghost)) {
            try await UpdateTemplate(repository: repo)(id: ghost, name: "X", sets: uniformBlock(exerciseIndex: 0))
        }
    }
}

struct InstantiateTemplateTests {
    private let today = DayDate(year: 2026, month: 7, day: 9)

    private func template() -> WorkoutTemplate {
        WorkoutTemplate(
            id: UUID(), name: "推日", source: .user, orderIndex: 0,
            sets: [
                PlanSet(id: UUID(), exerciseId: UUID(), exerciseIndex: 0, setIndex: 0,
                        targetWeight: .absolute(Weight(value: 100, unit: .kg)), targetReps: 5, restSec: 90),
                PlanSet(id: UUID(), exerciseId: UUID(), exerciseIndex: 1, setIndex: 0,
                        targetWeight: .absolute(Weight(value: 60, unit: .kg)), targetReps: 8),
            ],
            createdAt: Date(), updatedAt: Date()
        )
    }

    @Test func instantiateCopiesSetsAsSnapshotWithNewIds() async throws {
        let templateRepo = MockWorkoutTemplateRepository()
        let planRepo = MockPlanWorkoutRepository()
        let tpl = template()
        await templateRepo.seed([tpl])
        let instantiate = InstantiateTemplate(templateRepository: templateRepo, planRepository: planRepo, exerciseCatalog: MockPlanExerciseCatalog(), lastPerformedWeightLookup: MockLastPerformedWeightLookup())

        let plan = try await instantiate(templateId: tpl.id, date: today)

        #expect(plan.date == today)
        #expect(plan.status == .notStarted)
        #expect(plan.templateId == tpl.id)
        #expect(plan.name == "推日")
        #expect(plan.sets.count == 2)
        // 快照：set id 是新的，不等於範本的 set id
        #expect(Set(plan.sets.map(\.id)).isDisjoint(with: Set(tpl.sets.map(\.id))))
        // 目標值有被 copy 過來
        #expect(plan.sets.first?.targetWeight == .absolute(Weight(value: 100, unit: .kg)))
        #expect(plan.sets.first?.restSec == 90)
        // 已存進 plan repository
        #expect(try await planRepo.get(id: plan.id) != nil)
    }

    @Test func instantiateAssignsOrderIndexAfterExistingSameDay() async throws {
        let templateRepo = MockWorkoutTemplateRepository()
        let planRepo = MockPlanWorkoutRepository()
        let tpl = template()
        await templateRepo.seed([tpl])
        await planRepo.seed([PlanWorkout(id: UUID(), name: "先排的", date: today, orderIndex: 0)])
        let instantiate = InstantiateTemplate(templateRepository: templateRepo, planRepository: planRepo, exerciseCatalog: MockPlanExerciseCatalog(), lastPerformedWeightLookup: MockLastPerformedWeightLookup())

        let plan = try await instantiate(templateId: tpl.id, date: today)

        #expect(plan.orderIndex == 1)
    }

    @Test func instantiateMissingTemplateThrows() async throws {
        let ghost = UUID()
        let instantiate = InstantiateTemplate(
            templateRepository: MockWorkoutTemplateRepository(),
            planRepository: MockPlanWorkoutRepository(),
            exerciseCatalog: MockPlanExerciseCatalog(),
            lastPerformedWeightLookup: MockLastPerformedWeightLookup()
        )
        await #expect(throws: WorkoutTemplateRepositoryError.notFound(id: ghost)) {
            try await instantiate(templateId: ghost, date: today)
        }
    }
}
