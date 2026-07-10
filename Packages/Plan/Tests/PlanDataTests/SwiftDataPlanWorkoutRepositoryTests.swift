import Foundation
import PlanDomain
import SharedKernel
import SwiftData
import Testing

@testable import PlanData

struct SwiftDataPlanWorkoutRepositoryTests {
    private func makeRepository() throws -> any PlanWorkoutRepository {
        let container = try ModelContainer(
            for: Schema(PlanDataFactory.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return PlanDataFactory.makePlanWorkoutRepository(container: container)
    }

    private func planWorkout(date: DayDate?, order: Int, sets: Int = 2) -> PlanWorkout {
        PlanWorkout(
            id: UUID(), name: "推日", date: date, status: .notStarted, orderIndex: order,
            sets: (0..<sets).map {
                PlanSet(id: UUID(), exerciseId: UUID(), exerciseIndex: 0, setIndex: $0,
                        targetWeight: Weight(value: 100, unit: .kg), targetReps: 5)
            }
        )
    }

    @Test func saveThenGetRoundTrips() async throws {
        let repo = try makeRepository()
        let plan = planWorkout(date: DayDate(year: 2026, month: 7, day: 9), order: 0)

        try await repo.save(plan)
        let fetched = try await repo.get(id: plan.id)

        #expect(fetched == plan)
    }

    @Test func onDateFiltersByDay() async throws {
        let repo = try makeRepository()
        let day = DayDate(year: 2026, month: 7, day: 9)
        try await repo.save(planWorkout(date: day, order: 0))
        try await repo.save(planWorkout(date: DayDate(year: 2026, month: 7, day: 10), order: 1))
        try await repo.save(planWorkout(date: nil, order: 2))

        let onDay = try await repo.onDate(day)
        let cycle = try await repo.cycle()

        #expect(onDay.count == 1)
        #expect(cycle.count == 1)
    }

    @Test func saveReplacesAggregate() async throws {
        let repo = try makeRepository()
        var plan = planWorkout(date: nil, order: 0, sets: 3)
        try await repo.save(plan)

        plan.sets.removeLast()
        plan.name = "改過"
        try await repo.save(plan)

        let fetched = try await repo.get(id: plan.id)
        #expect(fetched?.sets.count == 2)
        #expect(fetched?.name == "改過")
    }

    @Test func usesExerciseReflectsPlanSets() async throws {
        let repo = try makeRepository()
        let plan = planWorkout(date: nil, order: 0, sets: 2)
        let usedExerciseId = plan.sets[0].exerciseId
        try await repo.save(plan)

        #expect(try await repo.usesExercise(usedExerciseId) == true)
        #expect(try await repo.usesExercise(UUID()) == false)
    }

    @Test func deleteRemoves() async throws {
        let repo = try makeRepository()
        let plan = planWorkout(date: nil, order: 0)
        try await repo.save(plan)

        try await repo.delete(id: plan.id)

        #expect(try await repo.get(id: plan.id) == nil)
    }
}
