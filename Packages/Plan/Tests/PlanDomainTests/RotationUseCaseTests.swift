import Foundation
import PlanDomain
import SharedKernel
import Testing

private func spec(_ name: String, exercise: UUID = UUID()) -> WorkoutSpec {
    WorkoutSpec(name: name, sets: [
        PlanSet(id: UUID(), exerciseId: exercise, exerciseIndex: 0, setIndex: 0,
                targetWeight: Weight(value: 60, unit: .kg), targetReps: 8, restSec: 60),
    ])
}

actor MockRotationRepository: RotationRepository {
    private var stored = Rotation()
    func seed(_ r: Rotation) { stored = r }
    func load() async throws -> Rotation { stored }
    func save(_ rotation: Rotation) async throws { stored = rotation }
    func usesExercise(_ exerciseId: UUID) async throws -> Bool {
        stored.workouts.contains { $0.sets.contains { $0.exerciseId == exerciseId } }
    }
}

struct RotationModelTests {
    @Test func currentAndAdvanceWrapAround() {
        let r = Rotation(workouts: [spec("A"), spec("B"), spec("C")], cursor: 0)
        #expect(r.current?.name == "A")
        #expect(r.advanced().current?.name == "B")
        #expect(r.advanced().advanced().advanced().current?.name == "A")  // 繞回
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

struct SaveRotationWorkoutsTests {
    @Test func replacesWorkoutsKeepingCursorClamped() async throws {
        let repo = MockRotationRepository()
        await repo.seed(Rotation(workouts: [spec("A"), spec("B"), spec("C")], cursor: 2))

        try await SaveRotationWorkouts(repository: repo)([spec("X")])  // 只剩 1 張

        let r = try await repo.load()
        #expect(r.workouts.map(\.name) == ["X"])
        #expect(r.cursor == 0)  // 2 clamp 到 [0,1)
    }
}

struct StartRotationTests {
    private let today = DayDate(year: 2026, month: 7, day: 23)

    @Test func materializesCurrentAndAdvancesCursor() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        await rotationRepo.seed(Rotation(workouts: [spec("推"), spec("拉")], cursor: 0))
        let start = StartRotation(rotationRepository: rotationRepo, planRepository: planRepo)

        let plan = try await start(date: today)

        #expect(plan?.name == "推")
        #expect(plan?.date == today)
        #expect(plan?.status == .notStarted)
        #expect(plan?.templateId == nil)
        #expect(plan?.sets.count == 1)
        // 已存進 plan repository
        #expect(try await planRepo.get(id: plan!.id) != nil)
        // 游標前進到「拉」
        #expect(try await rotationRepo.load().current?.name == "拉")
    }

    @Test func advancesOnStartNotCompletion() async throws {
        let rotationRepo = MockRotationRepository()
        let planRepo = MockPlanWorkoutRepository()
        await rotationRepo.seed(Rotation(workouts: [spec("A"), spec("B")], cursor: 0))
        let start = StartRotation(rotationRepository: rotationRepo, planRepository: planRepo)

        _ = try await start(date: today)                       // 開始 A → 游標到 B
        let second = try await start(date: today)              // 開始 B → 游標繞回 A

        #expect(second?.name == "B")
        #expect(try await rotationRepo.load().current?.name == "A")
    }

    @Test func emptyRotationReturnsNil() async throws {
        let start = StartRotation(rotationRepository: MockRotationRepository(), planRepository: MockPlanWorkoutRepository())
        #expect(try await start(date: today) == nil)
    }
}
