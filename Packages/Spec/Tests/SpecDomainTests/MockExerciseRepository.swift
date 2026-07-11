import Foundation
import SharedKernel
import SpecDomain

/// 純記憶體 mock：證明上層只依賴 protocol，不碰 SwiftData 也能完整測試。
actor MockExerciseRepository: ExerciseRepository {
    private(set) var storage: [UUID: Exercise] = [:]
    private(set) var listCallCount = 0

    func seed(_ exercises: [Exercise]) {
        for exercise in exercises {
            storage[exercise.id] = exercise
        }
    }

    func list(muscleGroup: MuscleGroup?) async throws -> [Exercise] {
        listCallCount += 1
        return storage.values
            .filter { muscleGroup == nil || $0.muscleGroup == muscleGroup }
            .sorted { $0.name < $1.name }
    }

    func get(id: UUID) async throws -> Exercise? {
        storage[id]
    }

    func create(_ exercise: Exercise) async throws {
        storage[exercise.id] = exercise
    }

    func update(_ exercise: Exercise) async throws {
        guard storage[exercise.id] != nil else {
            throw ExerciseRepositoryError.notFound(id: exercise.id)
        }
        storage[exercise.id] = exercise
    }

    func delete(id: UUID) async throws {
        guard storage.removeValue(forKey: id) != nil else {
            throw ExerciseRepositoryError.notFound(id: id)
        }
    }
}

extension Exercise {
    static func stub(
        id: UUID = UUID(),
        name: String = "臥推",
        muscleGroup: MuscleGroup = .chest,
        equipment: Equipment = .barbell,
        description: String? = nil
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            muscleGroup: muscleGroup,
            equipment: equipment,
            description: description,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
