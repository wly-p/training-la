import Foundation
import PlanDomain
import SharedKernel
import SwiftData

@Model
final class PlanWorkoutModel {
    @Attribute(.unique) var id: UUID
    var name: String?
    var date: String           // "yyyy-MM-dd"，一定綁定某天
    var statusRaw: String
    /// 來源課表範本；nil＝手動一次性排課。
    var templateId: UUID?
    var orderIndex: Int
    @Relationship(deleteRule: .cascade, inverse: \PlanSetModel.planWorkout)
    var sets: [PlanSetModel]

    init(id: UUID, name: String?, date: String, statusRaw: String, templateId: UUID?, orderIndex: Int, sets: [PlanSetModel] = []) {
        self.id = id
        self.name = name
        self.date = date
        self.statusRaw = statusRaw
        self.templateId = templateId
        self.orderIndex = orderIndex
        self.sets = sets
    }
}

@Model
final class PlanSetModel {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var exerciseIndex: Int
    var setIndex: Int
    var targetWeightValue: Double?
    var targetWeightUnitRaw: String?
    var targetReps: Int?
    var restSec: Int?
    var planWorkout: PlanWorkoutModel?

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

extension PlanWorkoutModel {
    convenience init(from planWorkout: PlanWorkout) {
        self.init(
            id: planWorkout.id,
            name: planWorkout.name,
            date: planWorkout.date.isoString,
            statusRaw: planWorkout.status.rawValue,
            templateId: planWorkout.templateId,
            orderIndex: planWorkout.orderIndex,
            sets: planWorkout.sets.map { PlanSetModel(from: $0) }
        )
    }

    func toDomain() -> PlanWorkout {
        PlanWorkout(
            id: id,
            name: name,
            date: DayDate(isoString: date) ?? DayDate(year: 1970, month: 1, day: 1),
            status: PlanWorkoutStatus(rawValue: statusRaw) ?? .notStarted,
            templateId: templateId,
            orderIndex: orderIndex,
            sets: sets
                .map { $0.toDomain() }
                .sorted { ($0.exerciseIndex, $0.setIndex) < ($1.exerciseIndex, $1.setIndex) }
        )
    }
}

extension PlanSetModel {
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
