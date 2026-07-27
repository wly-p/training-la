import Foundation
import PlanDomain
import SharedKernel
import Testing

private func spec(_ name: String, exercise: UUID = UUID()) -> WorkoutSpec {
    WorkoutSpec(name: name, sets: [
        PlanSet(id: UUID(), exerciseId: exercise, exerciseIndex: 0, setIndex: 0,
                targetWeight: .absolute(Weight(value: 60, unit: .kg)), targetReps: 8, restSec: 60),
    ])
}

actor MockRotationRepository: RotationRepository {
    private var stored: [UUID: Rotation] = [:]
    func seed(_ r: Rotation) { stored[r.id] = r }
    func all() async throws -> [Rotation] { stored.values.sorted { $0.orderIndex < $1.orderIndex } }
    func get(id: UUID) async throws -> Rotation? { stored[id] }
    func save(_ rotation: Rotation) async throws { stored[rotation.id] = rotation }
    func delete(id: UUID) async throws { stored[id] = nil }
    func usesExercise(_ exerciseId: UUID) async throws -> Bool {
        stored.values.contains { $0.workouts.contains { $0.sets.contains { $0.exerciseId == exerciseId } } }
    }
}

struct RotationModelTests {
    @Test func currentAndAdvanceWrapAround() {
        let r = Rotation(workouts: [spec("A"), spec("B"), spec("C")], cursor: 0)
        #expect(r.current?.name == "A")
        #expect(r.advanced().current?.name == "B")
        #expect(r.advanced().advanced().advanced().current?.name == "A")  // 繞回
    }

    @Test func advancePreservesIdentityAndActive() {
        let id = UUID()
        let r = Rotation(id: id, name: "推拉腿", workouts: [spec("A"), spec("B")], cursor: 0, isActive: true, orderIndex: 3)
        let next = r.advanced()
        #expect(next.id == id)
        #expect(next.name == "推拉腿")
        #expect(next.isActive == true)
        #expect(next.orderIndex == 3)
        #expect(next.current?.name == "B")
    }

    @Test func emptyRotationHasNoCurrent() {
        #expect(Rotation().current == nil)
        #expect(Rotation().advanced().current == nil)
    }

    @Test func cursorClampedOnInit() {
        // 5 % 2 = 1 → 指向第 2 張 B
        #expect(Rotation(workouts: [spec("A"), spec("B")], cursor: 5).current?.name == "B")
    }
}

struct CreateRotationTests {
    @Test func appendsWithIncreasingOrderIndex() async throws {
        let repo = MockRotationRepository()
        let create = CreateRotation(repository: repo)
        try await create(name: "推拉腿")
        try await create(name: "上下分化")

        let all = try await repo.all()
        #expect(all.map(\.name) == ["推拉腿", "上下分化"])
        #expect(all.map(\.orderIndex) == [0, 1])
        #expect(all.map(\.isActive) == [true, true])         // 預設啟用
        #expect(all.map(\.workouts.count) == [0, 0])
    }

    @Test func rejectsEmptyName() async throws {
        let repo = MockRotationRepository()
        await #expect(throws: PlanWorkoutValidationError.emptyName) {
            try await CreateRotation(repository: repo)(name: "   ")
        }
    }
}

struct SaveRotationWorkoutsTests {
    @Test func replacesWorkoutsKeepingCursorClamped() async throws {
        let repo = MockRotationRepository()
        let id = UUID()
        await repo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B"), spec("C")], cursor: 2))

        try await SaveRotationWorkouts(repository: repo)(id: id, workouts: [spec("X")])  // 只剩 1 張

        let r = try await repo.get(id: id)!
        #expect(r.workouts.map(\.name) == ["X"])
        #expect(r.cursor == 0)  // 2 clamp 到 [0,1)
        #expect(r.name == "R")  // 名稱不動
    }
}

struct SetRotationActiveTests {
    @Test func deactivatingPreservesCursor() async throws {
        let repo = MockRotationRepository()
        let id = UUID()
        await repo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B")], cursor: 1, isActive: true))

        try await SetRotationActive(repository: repo)(id: id, isActive: false)

        let r = try await repo.get(id: id)!
        #expect(r.isActive == false)
        #expect(r.cursor == 1)  // v3 8b：停用保留游標（停在原處，再啟用從此續）
    }

    @Test func activatingKeepsCursor() async throws {
        let repo = MockRotationRepository()
        let id = UUID()
        await repo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B")], cursor: 1, isActive: false))

        try await SetRotationActive(repository: repo)(id: id, isActive: true)

        let r = try await repo.get(id: id)!
        #expect(r.isActive == true)
        #expect(r.cursor == 1)  // 啟用不動游標
    }
}

struct StartRotationTests {
    private let today = DayDate(year: 2026, month: 7, day: 23)

    @Test func materializesCurrentAndAdvancesCursor() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "推拉", workouts: [spec("推"), spec("拉")], cursor: 0))
        let start = StartRotation(rotationRepository: rotationRepo, planRepository: planRepo, exerciseCatalog: MockPlanExerciseCatalog(), lastPerformedWeightLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup())

        let plan = try await start(id: id, date: today)

        #expect(plan?.name == "推")
        #expect(plan?.date == today)
        #expect(plan?.status == .notStarted)
        #expect(plan?.templateId == nil)
        #expect(plan?.sets.count == 1)
        // 已存進 plan repository
        #expect(try await planRepo.get(id: plan!.id) != nil)
        // 游標前進到「拉」
        #expect(try await rotationRepo.get(id: id)?.current?.name == "拉")
    }

    @Test func advancesOnStartNotCompletion() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B")], cursor: 0))
        let start = StartRotation(rotationRepository: rotationRepo, planRepository: planRepo, exerciseCatalog: MockPlanExerciseCatalog(), lastPerformedWeightLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup())

        _ = try await start(id: id, date: today)               // 開始 A → 游標到 B
        let second = try await start(id: id, date: today)       // 開始 B → 游標繞回 A

        #expect(second?.name == "B")
        #expect(try await rotationRepo.get(id: id)?.current?.name == "A")
    }

    @Test func unknownOrEmptyRotationReturnsNil() async throws {
        let rotationRepo = MockRotationRepository()
        let start = StartRotation(rotationRepository: rotationRepo, planRepository: MockPlanWorkoutRepository(), exerciseCatalog: MockPlanExerciseCatalog(), lastPerformedWeightLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup())
        // 不存在的 id
        #expect(try await start(id: UUID(), date: today) == nil)
        // 空循環
        let emptyId = UUID()
        await rotationRepo.seed(Rotation(id: emptyId, name: "空"))
        #expect(try await start(id: emptyId, date: today) == nil)
    }

    @Test func startIncrementsCompletedCountAndRounds() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B"), spec("C")], cursor: 0))
        let start = StartRotation(rotationRepository: rotationRepo, planRepository: planRepo, exerciseCatalog: MockPlanExerciseCatalog(), lastPerformedWeightLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup())

        for _ in 0..<3 { _ = try await start(id: id, date: today) }  // 開始三次＝跑完一輪

        let r = try await rotationRepo.get(id: id)!
        #expect(r.completedCount == 3)
        #expect(r.roundsCompleted == 1)          // 3 次 ÷ 3 範本 = 1 輪
        #expect(r.current?.name == "A")          // 游標繞回第一張
    }

    @Test func appliesRotationIntensityFactorWhenSlotHasNoOverride() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "R", workouts: [spec("A")], cursor: 0, intensityFactor: 0.5))
        let start = StartRotation(
            rotationRepository: rotationRepo, planRepository: planRepo, exerciseCatalog: MockPlanExerciseCatalog(),
            lastPerformedWeightLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup()
        )

        let plan = try await start(id: id, date: today)

        // spec("A") 目標 60kg，循環倍率 0.5 → 30kg（catalog 空、預設遞增單位 1，剛好整除）。
        #expect(plan?.sets.first?.targetWeight == .absolute(Weight(value: 30, unit: .kg)))
    }

    @Test func slotIntensityFactorOverridesRotationFactor() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        var workout = spec("A")
        workout.intensityFactor = 0.8   // 這一格覆寫，蓋掉循環層的 0.5
        await rotationRepo.seed(Rotation(id: id, name: "R", workouts: [workout], cursor: 0, intensityFactor: 0.5))
        let start = StartRotation(
            rotationRepository: rotationRepo, planRepository: planRepo, exerciseCatalog: MockPlanExerciseCatalog(),
            lastPerformedWeightLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup()
        )

        let plan = try await start(id: id, date: today)

        #expect(plan?.sets.first?.targetWeight == .absolute(Weight(value: 48, unit: .kg)))  // 60 × 0.8
    }
}

/// 13d 開始前預覽：跟 `StartRotationTests` 同樣的收斂邏輯，但關鍵差異是「不寫入、不動游標」——
/// 這是預覽跟真正開始唯一該有的行為差異，兩邊都要驗證到。
struct PreviewRotationWorkoutTests {
    private let makePreview: (any RotationRepository) -> PreviewRotationWorkout = { repo in
        PreviewRotationWorkout(
            rotationRepository: repo, exerciseCatalog: MockPlanExerciseCatalog(),
            lastPerformedWeightLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup()
        )
    }

    @Test func resolvesCurrentWorkoutSameAsStart() async throws {
        let rotationRepo = MockRotationRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "推拉", workouts: [spec("推"), spec("拉")], cursor: 0))
        let preview = makePreview(rotationRepo)

        let plan = try await preview(id: id)

        #expect(plan?.name == "推")
        #expect(plan?.sets.count == 1)
        #expect(plan?.sets.first?.targetWeight == .absolute(Weight(value: 60, unit: .kg)))
    }

    @Test func doesNotAdvanceCursorOrPersistAnything() async throws {
        let rotationRepo = MockRotationRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "推拉", workouts: [spec("推"), spec("拉")], cursor: 0))
        let preview = makePreview(rotationRepo)

        _ = try await preview(id: id)
        _ = try await preview(id: id)   // 呼叫兩次也不該有副作用累積

        let after = try await rotationRepo.get(id: id)!
        #expect(after.current?.name == "推")   // 游標沒動
        #expect(after.completedCount == 0)     // 次數沒累計
    }

    @Test func unknownOrEmptyRotationReturnsNil() async throws {
        let rotationRepo = MockRotationRepository()
        let preview = makePreview(rotationRepo)

        #expect(try await preview(id: UUID()) == nil)

        let emptyId = UUID()
        await rotationRepo.seed(Rotation(id: emptyId, name: "空"))
        #expect(try await preview(id: emptyId) == nil)
    }
}

struct SetRotationIntensityFactorTests {
    @Test func updatesIntensityFactor() async throws {
        let repo = MockRotationRepository()
        let id = UUID()
        await repo.seed(Rotation(id: id, name: "R", workouts: [spec("A")]))

        try await SetRotationIntensityFactor(repository: repo)(id: id, intensityFactor: 0.85)

        #expect(try await repo.get(id: id)?.intensityFactor == 0.85)
    }

    @Test func missingRotationThrowsNotFound() async throws {
        let repo = MockRotationRepository()
        let id = UUID()
        await #expect(throws: RotationRepositoryError.notFound(id: id)) {
            try await SetRotationIntensityFactor(repository: repo)(id: id, intensityFactor: 0.85)
        }
    }
}

struct AdvanceResetRotationTests {
    @Test func advanceMovesCursorWithoutCounting() async throws {
        let repo = MockRotationRepository()
        let id = UUID()
        await repo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B")], cursor: 0, completedCount: 5))

        try await AdvanceRotation(repository: repo)(id: id)

        let r = try await repo.get(id: id)!
        #expect(r.current?.name == "B")     // 游標前進
        #expect(r.completedCount == 5)      // 次數不變（手動跳不算完成）
    }

    @Test func resetZerosCursorAndCount() async throws {
        let repo = MockRotationRepository()
        let id = UUID()
        await repo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B")], cursor: 1, completedCount: 7))

        try await ResetRotation(repository: repo)(id: id)

        let r = try await repo.get(id: id)!
        #expect(r.cursor == 0)
        #expect(r.completedCount == 0)
        #expect(r.roundsCompleted == 0)
    }
}
