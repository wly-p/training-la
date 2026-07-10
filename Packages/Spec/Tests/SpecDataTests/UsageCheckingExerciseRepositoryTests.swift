import Foundation
import SharedKernel
import SpecDomain
import Testing

@testable import SpecData

private actor SpyBaseRepo: ExerciseRepository {
    private(set) var deletedIds: [UUID] = []
    var stored: [UUID: Exercise] = [:]

    func list(muscleGroup: MuscleGroup?) async throws -> [Exercise] { Array(stored.values) }
    func get(id: UUID) async throws -> Exercise? { stored[id] }
    func create(_ exercise: Exercise) async throws { stored[exercise.id] = exercise }
    func update(_ exercise: Exercise) async throws { stored[exercise.id] = exercise }
    func delete(id: UUID) async throws {
        deletedIds.append(id)
        stored[id] = nil
    }
}

private struct StubChecker: ExerciseUsageChecking {
    let used: Bool
    func isUsed(exerciseId: UUID) async throws -> Bool { used }
}

struct UsageCheckingExerciseRepositoryTests {
    private func exercise() -> Exercise {
        Exercise(id: UUID(), name: "臥推", muscleGroup: .chest, description: nil,
                 createdAt: Date(), updatedAt: Date())
    }

    @Test func deleteThrowsInUseWhenReferencedAndDoesNotTouchBase() async throws {
        let base = SpyBaseRepo()
        let ex = exercise()
        try await base.create(ex)
        let repo = UsageCheckingExerciseRepository(base: base, usageChecker: StubChecker(used: true))

        await #expect(throws: ExerciseRepositoryError.inUse(id: ex.id)) {
            try await repo.delete(id: ex.id)
        }
        #expect(await base.deletedIds.isEmpty) // 底層 delete 沒被呼叫
    }

    @Test func deleteProceedsWhenNotReferenced() async throws {
        let base = SpyBaseRepo()
        let ex = exercise()
        try await base.create(ex)
        let repo = UsageCheckingExerciseRepository(base: base, usageChecker: StubChecker(used: false))

        try await repo.delete(id: ex.id)

        #expect(await base.deletedIds == [ex.id])
    }

    @Test func nonDeleteOperationsPassThrough() async throws {
        let base = SpyBaseRepo()
        let repo = UsageCheckingExerciseRepository(base: base, usageChecker: StubChecker(used: true))
        let ex = exercise()

        try await repo.create(ex)
        #expect(try await repo.get(id: ex.id) == ex)
        #expect(try await repo.list(muscleGroup: nil).count == 1)
    }
}
