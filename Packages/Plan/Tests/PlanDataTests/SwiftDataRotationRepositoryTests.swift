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
        #expect(try await repo.load().workouts.isEmpty)
    }

    @Test func saveThenLoadRoundTripsOrderAndCursor() async throws {
        let repo = try makeRepository()
        try await repo.save(Rotation(workouts: [spec("推"), spec("拉"), spec("腿")], cursor: 1))

        let r = try await repo.load()
        #expect(r.workouts.map(\.name) == ["推", "拉", "腿"])
        #expect(r.cursor == 1)
        #expect(r.current?.name == "拉")
    }

    @Test func saveReplacesSingleton() async throws {
        let repo = try makeRepository()
        try await repo.save(Rotation(workouts: [spec("A"), spec("B")], cursor: 0))
        try await repo.save(Rotation(workouts: [spec("X")], cursor: 0))

        let r = try await repo.load()
        #expect(r.workouts.map(\.name) == ["X"])
    }

    @Test func usesExerciseReflectsRotationSets() async throws {
        let repo = try makeRepository()
        let used = UUID()
        try await repo.save(Rotation(workouts: [spec("推", exercise: used)], cursor: 0))

        #expect(try await repo.usesExercise(used) == true)
        #expect(try await repo.usesExercise(UUID()) == false)
    }
}
