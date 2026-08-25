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

    @Test func materializesCurrentWithoutAdvancingCursor() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "推拉", workouts: [spec("推"), spec("拉")], cursor: 0))
        let start = StartRotation(rotationRepository: rotationRepo, planRepository: planRepo, preferences: InMemoryTrainingPreferenceStore(), lastPerformedWeightLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup())

        let plan = try await start(id: id, date: today)

        #expect(plan?.name == "推")
        #expect(plan?.date == today)
        #expect(plan?.status == .notStarted)
        #expect(plan?.templateId == nil)
        #expect(plan?.sets.count == 1)
        // 已存進 plan repository
        #expect(try await planRepo.get(id: plan!.id) != nil)
        // 排課帶著來源循環，完成時才找得回來要推哪一組游標
        #expect(plan?.origin == .rotation)
        #expect(plan?.rotationId == id)
        // 游標**不動**：開始不等於做完，中途捨棄整場的話循環不該已經跳過一張。
        #expect(try await rotationRepo.get(id: id)?.current?.name == "推")
        #expect(try await rotationRepo.get(id: id)?.completedCount == 0)
    }

    /// 連按兩次「開始」而中間沒做完：兩張都是同一個 spec，游標原地不動。
    /// 舊行為是開始就推游標，所以第二張會變成 B——那正是「捨棄整場會跳掉一輪」的病根。
    @Test func startingTwiceWithoutFinishingKeepsGivingTheSameWorkout() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B")], cursor: 0))
        let start = StartRotation(rotationRepository: rotationRepo, planRepository: planRepo, preferences: InMemoryTrainingPreferenceStore(), lastPerformedWeightLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup())

        let first = try await start(id: id, date: today)
        let second = try await start(id: id, date: today)

        #expect(first?.name == "A")
        #expect(second?.name == "A")
        #expect(try await rotationRepo.get(id: id)?.current?.name == "A")
        #expect(try await rotationRepo.get(id: id)?.completedCount == 0)
    }

    @Test func unknownOrEmptyRotationReturnsNil() async throws {
        let rotationRepo = MockRotationRepository()
        let start = StartRotation(rotationRepository: rotationRepo, planRepository: MockPlanWorkoutRepository(), preferences: InMemoryTrainingPreferenceStore(), lastPerformedWeightLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup())
        // 不存在的 id
        #expect(try await start(id: UUID(), date: today) == nil)
        // 空循環
        let emptyId = UUID()
        await rotationRepo.seed(Rotation(id: emptyId, name: "空"))
        #expect(try await start(id: emptyId, date: today) == nil)
    }

    /// 開始不計次數：`completedCount` 與 `roundsCompleted` 是「做完幾張」，不是「按了幾次開始」。
    @Test func startingDoesNotCountAsCompletion() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B"), spec("C")], cursor: 0))
        let start = StartRotation(rotationRepository: rotationRepo, planRepository: planRepo, preferences: InMemoryTrainingPreferenceStore(), lastPerformedWeightLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup())

        for _ in 0..<3 { _ = try await start(id: id, date: today) }

        let r = try await rotationRepo.get(id: id)!
        #expect(r.completedCount == 0)
        #expect(r.roundsCompleted == 0)
        #expect(r.current?.name == "A")
    }

    @Test func appliesRotationIntensityFactorWhenSlotHasNoOverride() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "R", workouts: [spec("A")], cursor: 0, intensityFactor: 0.5))
        let start = StartRotation(
            rotationRepository: rotationRepo, planRepository: planRepo, preferences: InMemoryTrainingPreferenceStore(),
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
            rotationRepository: rotationRepo, planRepository: planRepo, preferences: InMemoryTrainingPreferenceStore(),
            lastPerformedWeightLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup()
        )

        let plan = try await start(id: id, date: today)

        // 60 × 0.8 = 48，再依級距偏好（預設 2.5）向下取整 → 47.5。
        // 級距改由使用者偏好決定之後，這裡不再是器材給的值（舊版空 catalog 會 fallback 成 1）。
        #expect(plan?.sets.first?.targetWeight == .absolute(Weight(value: 47.5, unit: .kg)))
    }
}

/// E1：循環游標的完整生命週期——開始 → 捨棄／完成／離開三條路徑。
///
/// 舊行為是 `StartRotation` 在建立排課的同時就推游標＋計次，所以「開始一場循環訓練然後
/// 中途捨棄」會讓循環白跳一張，當天還留下一張沒人會做的孤兒排課。
/// 現在推進改由 `MarkPlanWorkoutDone` 在**完成**時做，靠排課帶的 `rotationId` 找回是哪一組。
struct RotationCursorLifecycleTests {
    private let today = DayDate(year: 2026, month: 7, day: 23)

    private func makeStart(
        _ rotationRepo: MockRotationRepository, _ planRepo: MockPlanWorkoutRepository
    ) -> StartRotation {
        StartRotation(
            rotationRepository: rotationRepo, planRepository: planRepo,
            preferences: InMemoryTrainingPreferenceStore(),
            lastPerformedWeightLookup: MockLastPerformedWeightLookup(),
            abilityValueLookup: MockAbilityValueLookup()
        )
    }

    /// 開始 → 捨棄：游標與次數都不動，孤兒排課被清掉。
    @Test func startThenDiscardLeavesTheRotationWhereItWas() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B")], cursor: 0))

        let plan = try await makeStart(rotationRepo, planRepo)(id: id, date: today)
        try await DiscardRotationPlanWorkout(repository: planRepo)(id: plan!.id)

        let r = try await rotationRepo.get(id: id)!
        #expect(r.current?.name == "A")
        #expect(r.completedCount == 0)
        // 當天不留下孤兒排課
        #expect(try await planRepo.onDate(today).isEmpty)
    }

    /// 開始 → 完成：游標前進一格、次數 +1。重複標記完成不會再推。
    @Test func startThenFinishAdvancesExactlyOnce() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B")], cursor: 0))
        let markDone = MarkPlanWorkoutDone(repository: planRepo, rotationRepository: rotationRepo)

        let plan = try await makeStart(rotationRepo, planRepo)(id: id, date: today)
        try await markDone(id: plan!.id)

        var r = try await rotationRepo.get(id: id)!
        #expect(r.current?.name == "B")
        #expect(r.completedCount == 1)

        // 冪等：同一張再標記一次不該連跳兩格
        try await markDone(id: plan!.id)
        r = try await rotationRepo.get(id: id)!
        #expect(r.current?.name == "B")
        #expect(r.completedCount == 1)
    }

    /// 開始 → 離開（未完成）：不推進，排課仍在，下次回來可續。
    @Test func startThenLeaveKeepsThePlanForNextTime() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B")], cursor: 0))

        let plan = try await makeStart(rotationRepo, planRepo)(id: id, date: today)
        // 「離開」＝什麼都不做：沒有標記完成、也沒有捨棄。

        let r = try await rotationRepo.get(id: id)!
        #expect(r.current?.name == "A")
        #expect(r.completedCount == 0)
        #expect(try await planRepo.get(id: plan!.id)?.status == .notStarted)
    }

    /// 跑完整整一輪：三張都做完才算一輪，不是按了三次開始。
    @Test func finishingEveryWorkoutCompletesARound() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let id = UUID()
        await rotationRepo.seed(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B"), spec("C")], cursor: 0))
        let start = makeStart(rotationRepo, planRepo)
        let markDone = MarkPlanWorkoutDone(repository: planRepo, rotationRepository: rotationRepo)

        for offset in 0..<3 {
            let plan = try await start(id: id, date: today.adding(days: offset))
            try await markDone(id: plan!.id)
        }

        let r = try await rotationRepo.get(id: id)!
        #expect(r.completedCount == 3)
        #expect(r.roundsCompleted == 1)
        #expect(r.current?.name == "A")
    }

    /// 只刪循環派出的排課：手動／範本／長期課表排好的，捨棄訓練後要留著讓使用者重來。
    @Test func discardingOnlyRemovesRotationOwnedPlans() async throws {
        let planRepo = MockPlanWorkoutRepository()
        let manual = PlanWorkout(id: UUID(), name: "自己排的", date: today, origin: .manual, orderIndex: 0)
        let fromTemplate = PlanWorkout(id: UUID(), name: "範本來的", date: today, origin: .template, orderIndex: 1)
        await planRepo.seed([manual, fromTemplate])

        try await DiscardRotationPlanWorkout(repository: planRepo)(id: manual.id)
        try await DiscardRotationPlanWorkout(repository: planRepo)(id: fromTemplate.id)

        #expect(try await planRepo.get(id: manual.id) != nil)
        #expect(try await planRepo.get(id: fromTemplate.id) != nil)
    }

    /// 沒有 rotationId 的排課（手動、範本、長期課表）標記完成時，不該去碰任何循環。
    @Test func finishingANonRotationPlanTouchesNoRotation() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        let rotationId = UUID()
        await rotationRepo.seed(Rotation(id: rotationId, name: "R", workouts: [spec("A"), spec("B")], cursor: 0))
        let manual = PlanWorkout(id: UUID(), name: "自己排的", date: today, origin: .manual, orderIndex: 0)
        await planRepo.seed([manual])

        try await MarkPlanWorkoutDone(repository: planRepo, rotationRepository: rotationRepo)(id: manual.id)

        let r = try await rotationRepo.get(id: rotationId)!
        #expect(r.current?.name == "A")
        #expect(r.completedCount == 0)
        #expect(try await planRepo.get(id: manual.id)?.status == .done)
    }
}

/// 13d 開始前預覽：跟 `StartRotationTests` 同樣的收斂邏輯，但關鍵差異是「不寫入、不動游標」——
/// 這是預覽跟真正開始唯一該有的行為差異，兩邊都要驗證到。
struct PreviewRotationWorkoutTests {
    private let makePreview: (any RotationRepository) -> PreviewRotationWorkout = { repo in
        PreviewRotationWorkout(
            rotationRepository: repo, preferences: InMemoryTrainingPreferenceStore(),
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
