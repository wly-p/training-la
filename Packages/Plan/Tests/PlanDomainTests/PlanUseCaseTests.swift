import Foundation
import PlanDomain
import SharedKernel
import Testing

private let sampleDate = DayDate(year: 2026, month: 7, day: 9)

struct PlanCreateTests {
    private func draft(_ setCount: Int = 3) -> ExerciseTargetDraft {
        ExerciseTargetDraft(exerciseId: UUID(), setCount: setCount,
                            targetWeight: Weight(value: 100, unit: .kg), targetReps: 5)
    }

    @Test func createExpandsDraftsIntoIndexedSets() async throws {
        let repo = MockPlanWorkoutRepository()
        let create = CreatePlanWorkout(repository: repo)
        let squat = draft(3)
        let bench = ExerciseTargetDraft(exerciseId: UUID(), setCount: 1,
                                        targetWeight: Weight(value: 80, unit: .kg), targetReps: 5)

        let plan = try await create(name: "推日", date: sampleDate, drafts: [squat, bench])

        #expect(plan.sets.count == 4)
        #expect(plan.blocks.count == 2)
        #expect(plan.blocks[0].sets.map(\.setIndex) == [0, 1, 2])
        #expect(plan.blocks[1].exerciseIndex == 1)
        #expect(plan.blocks[1].sets[0].setIndex == 0)
    }

    @Test func reorderedDraftsRenumberExerciseIndexByNewOrder() async throws {
        // 對應「編輯排課時拖拉排序」：drafts 陣列被 move 後，儲存時 exerciseIndex 依新順序重編。
        let repo = MockPlanWorkoutRepository()
        let create = CreatePlanWorkout(repository: repo)
        let a = ExerciseTargetDraft(exerciseId: UUID(), setCount: 1, targetWeight: nil, targetReps: nil)
        let b = ExerciseTargetDraft(exerciseId: UUID(), setCount: 1, targetWeight: nil, targetReps: nil)
        let c = ExerciseTargetDraft(exerciseId: UUID(), setCount: 1, targetWeight: nil, targetReps: nil)

        // 模擬把 c 拖到最前：[a, b, c] → [c, a, b]（UI 端由 onMove/Array.move 完成）
        let reordered = [c, a, b]

        let plan = try await create(name: "推日", date: sampleDate, drafts: reordered)

        #expect(plan.blocks.map(\.exerciseIndex) == [0, 1, 2])
        #expect(plan.blocks.map(\.exerciseId) == [c.exerciseId, a.exerciseId, b.exerciseId])
    }

    @Test func createRejectsEmptyDrafts() async throws {
        let create = CreatePlanWorkout(repository: MockPlanWorkoutRepository())
        await #expect(throws: PlanWorkoutValidationError.empty) {
            try await create(name: "空", date: sampleDate, drafts: [])
        }
    }

    @Test func createCarriesRestSecondsToEverySet() async throws {
        let repo = MockPlanWorkoutRepository()
        let create = CreatePlanWorkout(repository: repo)
        let withRest = ExerciseTargetDraft(exerciseId: UUID(), setCount: 3,
                                           targetWeight: Weight(value: 100, unit: .kg),
                                           targetReps: 5, restSec: 90)

        let plan = try await create(name: "推日", date: sampleDate, drafts: [withRest])

        #expect(plan.sets.allSatisfy { $0.restSec == 90 })
    }

    @Test func createAssignsIncreasingOrderIndexPerDate() async throws {
        let repo = MockPlanWorkoutRepository()
        let create = CreatePlanWorkout(repository: repo)

        let first = try await create(name: "A", date: sampleDate, drafts: [draft()])
        let second = try await create(name: "B", date: sampleDate, drafts: [draft()])

        #expect(first.orderIndex == 0)
        #expect(second.orderIndex == 1)
    }
}

struct TodaysWorkoutTests {
    private let today = DayDate(year: 2026, month: 7, day: 9)

    private func planWorkout(
        name: String,
        date: DayDate,
        status: PlanWorkoutStatus,
        orderIndex: Int
    ) -> PlanWorkout {
        PlanWorkout(id: UUID(), name: name, date: date, status: status, orderIndex: orderIndex,
                    sets: [PlanSet(id: UUID(), exerciseId: UUID(), exerciseIndex: 0, setIndex: 0,
                                   targetWeight: nil, targetReps: nil)])
    }

    @Test func returnsSmallestOrderIndexNotStartedForToday() async throws {
        let repo = MockPlanWorkoutRepository()
        await repo.seed([
            planWorkout(name: "第二張", date: today, status: .notStarted, orderIndex: 5),
            planWorkout(name: "第一張", date: today, status: .notStarted, orderIndex: 1),
        ])
        let todays = TodaysWorkout(repository: repo, today: { today })

        #expect(try await todays()?.name == "第一張")
    }

    @Test func skipsDoneAndPicksNextNotStarted() async throws {
        let repo = MockPlanWorkoutRepository()
        await repo.seed([
            planWorkout(name: "做完了", date: today, status: .done, orderIndex: 0),
            planWorkout(name: "還沒做", date: today, status: .notStarted, orderIndex: 1),
        ])
        let todays = TodaysWorkout(repository: repo, today: { today })

        #expect(try await todays()?.name == "還沒做")
    }

    @Test func ignoresOtherDays() async throws {
        let repo = MockPlanWorkoutRepository()
        await repo.seed([
            planWorkout(name: "明天", date: DayDate(year: 2026, month: 7, day: 10), status: .notStarted, orderIndex: 0),
        ])
        let todays = TodaysWorkout(repository: repo, today: { today })

        #expect(try await todays() == nil)
    }

    @Test func returnsNilWhenTodayAllDone() async throws {
        let repo = MockPlanWorkoutRepository()
        await repo.seed([
            planWorkout(name: "做完了", date: today, status: .done, orderIndex: 0),
        ])
        let todays = TodaysWorkout(repository: repo, today: { today })

        #expect(try await todays() == nil)
    }

    @Test func returnsNilWhenNoPlans() async throws {
        let todays = TodaysWorkout(repository: MockPlanWorkoutRepository(), today: { today })
        #expect(try await todays() == nil)
    }
}

struct MarkPlanDoneTests {
    @Test func marksDone() async throws {
        let repo = MockPlanWorkoutRepository()
        let plan = PlanWorkout(id: UUID(), name: "推", date: sampleDate, status: .notStarted, orderIndex: 0)
        await repo.seed([plan])

        try await MarkPlanWorkoutDone(repository: repo)(id: plan.id)

        #expect(try await repo.get(id: plan.id)?.status == .done)
    }

    @Test func missingIdIsNoop() async throws {
        let repo = MockPlanWorkoutRepository()
        // 不應丟錯（排課可能已被刪）
        try await MarkPlanWorkoutDone(repository: repo)(id: UUID())
    }
}

struct RevertPlanDoneTests {
    @Test func revertsDoneToNotStarted() async throws {
        let repo = MockPlanWorkoutRepository()
        let plan = PlanWorkout(id: UUID(), name: "推", date: sampleDate, status: .done, orderIndex: 0)
        await repo.seed([plan])

        try await RevertPlanWorkoutDone(repository: repo)(id: plan.id)

        #expect(try await repo.get(id: plan.id)?.status == .notStarted)
    }

    @Test func missingIdIsNoop() async throws {
        try await RevertPlanWorkoutDone(repository: MockPlanWorkoutRepository())(id: UUID())
    }
}
