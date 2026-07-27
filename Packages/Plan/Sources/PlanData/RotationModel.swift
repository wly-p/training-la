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
    /// 累計已開始訓練次數。新欄位；預設 0（未發佈、無 migration 需求）。
    var completedCount: Int = 0
    /// 這組循環的強度倍率。新欄位；預設 1.0（未發佈、無 migration 需求）。
    var intensityFactor: Double = 1.0
    @Relationship(deleteRule: .cascade, inverse: \RotationWorkoutModel.rotation)
    var workouts: [RotationWorkoutModel]

    init(
        id: UUID, name: String, cursor: Int, isActive: Bool, orderIndex: Int, completedCount: Int = 0,
        intensityFactor: Double = 1.0, workouts: [RotationWorkoutModel] = []
    ) {
        self.id = id
        self.name = name
        self.cursor = cursor
        self.isActive = isActive
        self.orderIndex = orderIndex
        self.completedCount = completedCount
        self.intensityFactor = intensityFactor
        self.workouts = workouts
    }
}

@Model
final class RotationWorkoutModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var orderIndex: Int
    /// 這一格的強度倍率覆寫；nil＝繼承循環的 `intensityFactor`。新欄位；預設 nil。
    var intensityFactor: Double?
    var rotation: RotationModel?
    @Relationship(deleteRule: .cascade, inverse: \RotationSetModel.workout)
    var sets: [RotationSetModel]

    init(id: UUID, name: String, orderIndex: Int, intensityFactor: Double? = nil, sets: [RotationSetModel] = []) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
        self.intensityFactor = intensityFactor
        self.sets = sets
    }
}

@Model
final class RotationSetModel {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var exerciseIndex: Int
    var setIndex: Int
    /// "absolute" ／ "relativeToLast"；nil＝沒有目標重量。見 `WeightExpressionCoding`。
    var targetWeightKindRaw: String?
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
        targetWeightKindRaw: String?,
        targetWeightValue: Double?,
        targetWeightUnitRaw: String?,
        targetReps: Int?,
        restSec: Int?
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.targetWeightKindRaw = targetWeightKindRaw
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
            completedCount: rotation.completedCount,
            intensityFactor: rotation.intensityFactor,
            workouts: rotation.workouts.enumerated().map { index, spec in
                RotationWorkoutModel(from: spec, orderIndex: index)
            }
        )
    }

    func toDomain() -> Rotation {
        let specs = workouts
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { $0.toDomain() }
        return Rotation(
            id: id, name: name, workouts: specs, cursor: cursor, isActive: isActive, orderIndex: orderIndex,
            completedCount: completedCount, intensityFactor: intensityFactor
        )
    }
}

extension RotationWorkoutModel {
    convenience init(from spec: WorkoutSpec, orderIndex: Int) {
        self.init(
            id: spec.id,
            name: spec.name,
            orderIndex: orderIndex,
            intensityFactor: spec.intensityFactor,
            sets: spec.sets.map { RotationSetModel(from: $0) }
        )
    }

    func toDomain() -> WorkoutSpec {
        WorkoutSpec(
            id: id,
            name: name,
            sets: sets
                .map { $0.toDomain() }
                .sorted { ($0.exerciseIndex, $0.setIndex) < ($1.exerciseIndex, $1.setIndex) },
            intensityFactor: intensityFactor
        )
    }
}

extension RotationSetModel {
    convenience init(from set: PlanSet) {
        let encoded = WeightExpressionCoding.encode(set.targetWeight)
        self.init(
            id: set.id,
            exerciseId: set.exerciseId,
            exerciseIndex: set.exerciseIndex,
            setIndex: set.setIndex,
            targetWeightKindRaw: encoded.kind,
            targetWeightValue: encoded.value,
            targetWeightUnitRaw: encoded.unit,
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
            targetWeight: WeightExpressionCoding.decode(
                kind: targetWeightKindRaw, value: targetWeightValue, unitRaw: targetWeightUnitRaw
            ),
            targetReps: targetReps,
            restSec: restSec
        )
    }
}
