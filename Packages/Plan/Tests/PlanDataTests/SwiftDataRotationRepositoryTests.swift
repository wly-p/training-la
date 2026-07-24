import Foundation
import PlanDomain
import SharedKernel
import SwiftData
import Testing

@testable import PlanData

struct SwiftDataRotationRepositoryTests {
    private func makeRepository() throws -> any RotationRepository {
        let container = try ModelContainer(
            for: Schema(PlanDataFactory.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return PlanDataFactory.makeRotationRepository(container: container)
    }

    private func spec(_ name: String, exercise: UUID = UUID()) -> WorkoutSpec {
        WorkoutSpec(name: name, sets: [
            PlanSet(id: UUID(), exerciseId: exercise, exerciseIndex: 0, setIndex: 0,
                    targetWeight: Weight(value: 100, unit: .kg), targetReps: 5, restSec: 90),
        ])
    }

    @Test func emptyWhenNeverSaved() async throws {
        let repo = try makeRepository()
        #expect(try await repo.all().isEmpty)
    }

    @Test func saveThenGetRoundTripsAllFields() async throws {
        let repo = try makeRepository()
        let id = UUID()
        try await repo.save(Rotation(
            id: id, name: "推拉腿", workouts: [spec("推"), spec("拉"), spec("腿")],
            cursor: 1, isActive: false, orderIndex: 2
        ))

        let r = try await repo.get(id: id)!
        #expect(r.name == "推拉腿")
        #expect(r.workouts.map(\.name) == ["推", "拉", "腿"])
        #expect(r.cursor == 1)
        #expect(r.current?.name == "拉")
        #expect(r.isActive == false)
        #expect(r.orderIndex == 2)
    }

    @Test func allSortsByOrderIndex() async throws {
        let repo = try makeRepository()
        try await repo.save(Rotation(id: UUID(), name: "B", orderIndex: 1))
        try await repo.save(Rotation(id: UUID(), name: "A", orderIndex: 0))
        try await repo.save(Rotation(id: UUID(), name: "C", orderIndex: 2))

        #expect(try await repo.all().map(\.name) == ["A", "B", "C"])
    }

    @Test func saveUpsertsById() async throws {
        let repo = try makeRepository()
        let id = UUID()
        try await repo.save(Rotation(id: id, name: "R", workouts: [spec("A"), spec("B")], orderIndex: 0))
        try await repo.save(Rotation(id: id, name: "R2", workouts: [spec("X")], orderIndex: 0))

        #expect(try await repo.all().count == 1)
        let r = try await repo.get(id: id)!
        #expect(r.name == "R2")
        #expect(r.workouts.map(\.name) == ["X"])
    }

    @Test func deleteRemovesOne() async throws {
        let repo = try makeRepository()
        let keep = UUID()
        let drop = UUID()
        try await repo.save(Rotation(id: keep, name: "keep", orderIndex: 0))
        try await repo.save(Rotation(id: drop, name: "drop", orderIndex: 1))

        try await repo.delete(id: drop)

        #expect(try await repo.all().map(\.name) == ["keep"])
    }

    @Test func usesExerciseReflectsRotationSets() async throws {
        let repo = try makeRepository()
        let used = UUID()
        try await repo.save(Rotation(id: UUID(), name: "R", workouts: [spec("推", exercise: used)], orderIndex: 0))

        #expect(try await repo.usesExercise(used) == true)
        #expect(try await repo.usesExercise(UUID()) == false)
    }
}
