import Foundation
import SharedKernel
import SpecDomain
import SwiftData

/// SwiftData 持久化模型。不得漏出 SpecData：對外邊界一律轉成 `Exercise`。
@Model
final class ExerciseModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroupRaw: String
    var detail: String?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID, name: String, muscleGroupRaw: String, detail: String?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.muscleGroupRaw = muscleGroupRaw
        self.detail = detail
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ExerciseModel {
    convenience init(from exercise: Exercise) {
        self.init(
            id: exercise.id,
            name: exercise.name,
            muscleGroupRaw: exercise.muscleGroup.rawValue,
            detail: exercise.description,
            createdAt: exercise.createdAt,
            updatedAt: exercise.updatedAt
        )
    }

    func toDomain() -> Exercise {
        Exercise(
            id: id,
            name: name,
            muscleGroup: MuscleGroup(rawValue: muscleGroupRaw) ?? .other,
            description: detail,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(_ exercise: Exercise) {
        name = exercise.name
        muscleGroupRaw = exercise.muscleGroup.rawValue
        detail = exercise.description
        updatedAt = exercise.updatedAt
    }
}
