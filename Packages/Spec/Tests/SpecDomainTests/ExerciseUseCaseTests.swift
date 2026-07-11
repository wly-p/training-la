import Foundation
import SharedKernel
import SpecDomain
import Testing

struct ExerciseUseCaseTests {
    @Test func createAssignsIdentityAndTimestamps() async throws {
        let repo = MockExerciseRepository()
        let fixedID = UUID()
        let fixedDate = Date(timeIntervalSince1970: 1_000)
        let create = CreateExercise(repository: repo, makeID: { fixedID }, now: { fixedDate })

        let created = try await create(name: "  深蹲  ", muscleGroup: .legs, equipment: .barbell, description: nil)

        #expect(created.id == fixedID)
        #expect(created.name == "深蹲") // 前後空白要被修掉
        #expect(created.equipment == .barbell)
        #expect(created.createdAt == fixedDate)
        #expect(created.updatedAt == fixedDate)
        #expect(try await repo.get(id: fixedID) == created)
    }

    @Test func createRejectsEmptyName() async throws {
        let create = CreateExercise(repository: MockExerciseRepository())

        await #expect(throws: ExerciseValidationError.emptyName) {
            try await create(name: "   ", muscleGroup: .chest, equipment: .barbell, description: nil)
        }
    }

    @Test func createRejectsOverlongName() async throws {
        let create = CreateExercise(repository: MockExerciseRepository())

        await #expect(throws: ExerciseValidationError.nameTooLong(max: 100)) {
            try await create(name: String(repeating: "推", count: 101), muscleGroup: .chest, equipment: .barbell, description: nil)
        }
    }

    @Test func listPassesFilterThrough() async throws {
        let repo = MockExerciseRepository()
        await repo.seed([
            .stub(name: "臥推", muscleGroup: .chest),
            .stub(name: "深蹲", muscleGroup: .legs),
        ])
        let list = ListExercises(repository: repo)

        let legsOnly = try await list(muscleGroup: .legs)

        #expect(legsOnly.map(\.name) == ["深蹲"])
    }

    @Test func updateEditsFieldsAndBumpsUpdatedAt() async throws {
        let repo = MockExerciseRepository()
        let original = Exercise.stub(name: "臥推", muscleGroup: .chest)
        await repo.seed([original])
        let later = Date(timeIntervalSince1970: 9_999)
        let update = UpdateExercise(repository: repo, now: { later })

        let updated = try await update(id: original.id, name: "上斜臥推", muscleGroup: .chest, equipment: .dumbbell, description: "30度")

        #expect(updated.name == "上斜臥推")
        #expect(updated.equipment == .dumbbell)
        #expect(updated.description == "30度")
        #expect(updated.updatedAt == later)
        #expect(updated.createdAt == original.createdAt)
    }

    @Test func updateMissingExerciseThrowsNotFound() async throws {
        let update = UpdateExercise(repository: MockExerciseRepository())
        let ghost = UUID()

        await #expect(throws: ExerciseRepositoryError.notFound(id: ghost)) {
            try await update(id: ghost, name: "硬舉", muscleGroup: .back, equipment: .barbell, description: nil)
        }
    }

    @Test func deleteRemovesFromRepository() async throws {
        let repo = MockExerciseRepository()
        let exercise = Exercise.stub()
        await repo.seed([exercise])
        let delete = DeleteExercise(repository: repo)

        try await delete(id: exercise.id)

        #expect(try await repo.get(id: exercise.id) == nil)
    }
}
