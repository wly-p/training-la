import Foundation
import PlanDomain
import SharedKernel
import Testing

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

        let plan = try await create(name: "推日", date: nil, drafts: [squat, bench])

        #expect(plan.sets.count == 4)
        #expect(plan.blocks.count == 2)
        #expect(plan.blocks[0].sets.map(\.setIndex) == [0, 1, 2])
        #expect(plan.blocks[1].exerciseIndex == 1)
        #expect(plan.blocks[1].sets[0].setIndex == 0)
    }

    @Test func createRejectsEmptyDrafts() async throws {
        let create = CreatePlanWorkout(repository: MockPlanWorkoutRepository())
        await #expect(throws: PlanWorkoutValidationError.empty) {
            try await create(name: "空", date: nil, drafts: [])
        }
    }

    @Test func createAssignsIncreasingOrderIndex() async throws {
        let repo = MockPlanWorkoutRepository()
        let create = CreatePlanWorkout(repository: repo)

        let first = try await create(name: "A", date: nil, drafts: [draft()])
        let second = try await create(name: "B", date: nil, drafts: [draft()])

        #expect(first.orderIndex == 0)
        #expect(second.orderIndex == 1)
    }
}

struct TodaysWorkoutTests {
    private let today = DayDate(year: 2026, month: 7, day: 9)

    private func planWorkout(
        name: String,
        date: DayDate?,
        status: PlanWorkoutStatus,
        orderIndex: Int
    ) -> PlanWorkout {
        PlanWorkout(id: UUID(), name: name, date: date, status: status, orderIndex: orderIndex,
                    sets: [PlanSet(id: UUID(), exerciseId: UUID(), exerciseIndex: 0, setIndex: 0,
                                   targetWeight: nil, targetReps: nil)])
    }

    @Test func prefersDatedWorkoutForToday() async throws {
        let repo = MockPlanWorkoutRepository()
        await repo.seed([
            planWorkout(name: "今天推日", date: today, status: .notStarted, orderIndex: 5),
            planWorkout(name: "循環腿日", date: nil, status: .notStarted, orderIndex: 0),
        ])
        let todays = TodaysWorkout(repository: repo, today: { today })

        let result = try await todays()

        #expect(result?.name == "今天推日")
    }

    @Test func cycleReturnsSmallestNotStarted() async throws {
        let repo = MockPlanWorkoutRepository()
        await repo.seed([
            planWorkout(name: "推", date: nil, status: .done, orderIndex: 0),
            planWorkout(name: "拉", date: nil, status: .notStarted, orderIndex: 1),
            planWorkout(name: "腿", date: nil, status: .notStarted, orderIndex: 2),
        ])
        let todays = TodaysWorkout(repository: repo, today: { today })

        let result = try await todays()

        #expect(result?.name == "拉")
    }

    @Test func cycleResetsWhenAllDone() async throws {
        let repo = MockPlanWorkoutRepository()
        await repo.seed([
            planWorkout(name: "推", date: nil, status: .done, orderIndex: 0),
            planWorkout(name: "拉", date: nil, status: .done, orderIndex: 1),
        ])
        let todays = TodaysWorkout(repository: repo, today: { today })

        let result = try await todays()

        // 全部 done → 繞回第一個，且已被重設為 not_started
        #expect(result?.name == "推")
        let stored = try await repo.cycle()
        #expect(stored.allSatisfy { $0.status == .notStarted })
    }

    @Test func returnsNilWhenNoPlans() async throws {
        let todays = TodaysWorkout(repository: MockPlanWorkoutRepository(), today: { today })
        #expect(try await todays() == nil)
    }

    @Test func datedPlanAllDoneReturnsNilNotCycle() async throws {
        let repo = MockPlanWorkoutRepository()
        await repo.seed([
            planWorkout(name: "今天做完了", date: today, status: .done, orderIndex: 0),
            planWorkout(name: "循環腿日", date: nil, status: .notStarted, orderIndex: 1),
        ])
        let todays = TodaysWorkout(repository: repo, today: { today })

        // 今天指定日的做完了 → 今天沒待辦（不繞去循環）
        #expect(try await todays() == nil)
    }
}

struct MarkPlanDoneTests {
    @Test func marksDone() async throws {
        let repo = MockPlanWorkoutRepository()
        let plan = PlanWorkout(id: UUID(), name: "推", date: nil, status: .notStarted, orderIndex: 0)
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
