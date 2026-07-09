import Foundation
import SharedKernel
import SwiftData
import TrainingDomain

/// SwiftData 持久化模型（不外漏）。day 存 ISO 字串（"yyyy-MM-dd"），可直接排序。
@Model
final class WorkoutModel {
    @Attribute(.unique) var id: UUID
    var day: String
    var startedAt: Date?
    var endedAt: Date?
    var overallFeeling: Int?
    var note: String?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSetModel.workout)
    var sets: [WorkoutSetModel]

    init(
        id: UUID,
        day: String,
        startedAt: Date?,
        endedAt: Date?,
        overallFeeling: Int?,
        note: String?,
        sets: [WorkoutSetModel] = []
    ) {
        self.id = id
        self.day = day
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.overallFeeling = overallFeeling
        self.note = note
        self.sets = sets
    }
}

@Model
final class WorkoutSetModel {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var exerciseIndex: Int
    var setIndex: Int
    var weightValue: Double
    var weightUnitRaw: String
    var reps: Int
    var statusRaw: String
    var targetWeightValue: Double?
    var targetWeightUnitRaw: String?
    var targetReps: Int?
    var workout: WorkoutModel?

    init(
        id: UUID,
        exerciseId: UUID,
        exerciseIndex: Int,
        setIndex: Int,
        weightValue: Double,
        weightUnitRaw: String,
        reps: Int,
        statusRaw: String,
        targetWeightValue: Double?,
        targetWeightUnitRaw: String?,
        targetReps: Int?
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.weightValue = weightValue
        self.weightUnitRaw = weightUnitRaw
        self.reps = reps
        self.statusRaw = statusRaw
        self.targetWeightValue = targetWeightValue
        self.targetWeightUnitRaw = targetWeightUnitRaw
        self.targetReps = targetReps
    }
}

// MARK: - Mapper

extension WorkoutModel {
    convenience init(from workout: Workout) {
        self.init(
            id: workout.id,
            day: workout.day.isoString,
            startedAt: workout.startedAt,
            endedAt: workout.endedAt,
            overallFeeling: workout.overallFeeling,
            note: workout.note,
            sets: workout.sets.map { WorkoutSetModel(from: $0) }
        )
    }

    func toDomain() -> Workout {
        Workout(
            id: id,
            day: DayDate(isoString: day) ?? DayDate(year: 1970, month: 1, day: 1),
            startedAt: startedAt,
            endedAt: endedAt,
            overallFeeling: overallFeeling,
            note: note,
            sets: sets
                .map { $0.toDomain() }
                .sorted { ($0.exerciseIndex, $0.setIndex) < ($1.exerciseIndex, $1.setIndex) }
        )
    }
}

extension WorkoutSetModel {
    convenience init(from set: WorkoutSet) {
        self.init(
            id: set.id,
            exerciseId: set.exerciseId,
            exerciseIndex: set.exerciseIndex,
            setIndex: set.setIndex,
            weightValue: set.weight.value,
            weightUnitRaw: set.weight.unit.rawValue,
            reps: set.reps,
            statusRaw: set.status.rawValue,
            targetWeightValue: set.targetWeight?.value,
            targetWeightUnitRaw: set.targetWeight?.unit.rawValue,
            targetReps: set.targetReps
        )
    }

    func toDomain() -> WorkoutSet {
        WorkoutSet(
            id: id,
            exerciseId: exerciseId,
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            weight: Weight(
                value: weightValue,
                unit: WeightUnit(rawValue: weightUnitRaw) ?? .kg
            ),
            reps: reps,
            status: WorkoutSetStatus(rawValue: statusRaw) ?? .done,
            targetWeight: targetWeightValue.map {
                Weight(value: $0, unit: WeightUnit(rawValue: targetWeightUnitRaw ?? "kg") ?? .kg)
            },
            targetReps: targetReps
        )
    }
}
