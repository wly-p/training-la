import Foundation
import PlanDomain
import SharedKernel
import SwiftData

@Model
final class RotationModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var cursor: Int
    var isActive: Bool
    var orderIndex: Int
    @Relationship(deleteRule: .cascade, inverse: \RotationWorkoutModel.rotation)
    var workouts: [RotationWorkoutModel]

    init(id: UUID, name: String, cursor: Int, isActive: Bool, orderIndex: Int, workouts: [RotationWorkoutModel] = []) {
        self.id = id
        self.name = name
        self.cursor = cursor
        self.isActive = isActive
        self.orderIndex = orderIndex
        self.workouts = workouts
    }
}

@Model
final class RotationWorkoutModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var orderIndex: Int
    var rotation: RotationModel?
    @Relationship(deleteRule: .cascade, inverse: \RotationSetModel.workout)
    var sets: [RotationSetModel]

    init(id: UUID, name: String, orderIndex: Int, sets: [RotationSetModel] = []) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
        self.sets = sets
    }
}

@Model
final class RotationSetModel {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var exerciseIndex: Int
    var setIndex: Int
    var targetWeightValue: Double?
    var targetWeightUnitRaw: String?
    var targetReps: Int?
    var restSec: Int?
    var workout: RotationWorkoutModel?

    init(
        id: UUID,
        exerciseId: UUID,
        exerciseIndex: Int,
        setIndex: Int,
        targetWeightValue: Double?,
        targetWeightUnitRaw: String?,
        targetReps: Int?,
        restSec: Int?
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.targetWeightValue = targetWeightValue
        self.targetWeightUnitRaw = targetWeightUnitRaw
        self.targetReps = targetReps
        self.restSec = restSec
    }
}

// MARK: - Mapper

extension RotationModel {
    convenience init(from rotation: Rotation) {
        self.init(
            id: rotation.id,
            name: rotation.name,
            cursor: rotation.cursor,
            isActive: rotation.isActive,
            orderIndex: rotation.orderIndex,
            workouts: rotation.workouts.enumerated().map { index, spec in
                RotationWorkoutModel(from: spec, orderIndex: index)
            }
        )
    }

    func toDomain() -> Rotation {
        let specs = workouts
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { $0.toDomain() }
        return Rotation(id: id, name: name, workouts: specs, cursor: cursor, isActive: isActive, orderIndex: orderIndex)
    }
}

extension RotationWorkoutModel {
    convenience init(from spec: WorkoutSpec, orderIndex: Int) {
        self.init(
            id: spec.id,
            name: spec.name,
            orderIndex: orderIndex,
            sets: spec.sets.map { RotationSetModel(from: $0) }
        )
    }

    func toDomain() -> WorkoutSpec {
        WorkoutSpec(
            id: id,
            name: name,
            sets: sets
                .map { $0.toDomain() }
                .sorted { ($0.exerciseIndex, $0.setIndex) < ($1.exerciseIndex, $1.setIndex) }
        )
    }
}

extension RotationSetModel {
    convenience init(from set: PlanSet) {
        self.init(
            id: set.id,
            exerciseId: set.exerciseId,
            exerciseIndex: set.exerciseIndex,
            setIndex: set.setIndex,
            targetWeightValue: set.targetWeight?.value,
            targetWeightUnitRaw: set.targetWeight?.unit.rawValue,
            targetReps: set.targetReps,
            restSec: set.restSec
        )
    }

    func toDomain() -> PlanSet {
        PlanSet(
            id: id,
            exerciseId: exerciseId,
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            targetWeight: targetWeightValue.map {
                Weight(value: $0, unit: WeightUnit(rawValue: targetWeightUnitRaw ?? "kg") ?? .kg)
            },
            targetReps: targetReps,
            restSec: restSec
        )
    }
}
