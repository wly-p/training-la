import Foundation
import SharedKernel
import SwiftData
import TrainingDomain

/// SwiftData 持久化模型（不外漏）。day 存 ISO 字串（"yyyy-MM-dd"），可直接排序。
@Model
final class WorkoutModel {
    @Attribute(.unique) var id: UUID
    var day: String
    var planWorkoutId: UUID?
    var startedAt: Date?
    var endedAt: Date?
    var overallFeeling: Int?
    var note: String?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSetModel.workout)
    var sets: [WorkoutSetModel]

    init(
        id: UUID,
        day: String,
        planWorkoutId: UUID?,
        startedAt: Date?,
        endedAt: Date?,
        overallFeeling: Int?,
        note: String?,
        sets: [WorkoutSetModel] = []
    ) {
        self.id = id
        self.day = day
        self.planWorkoutId = planWorkoutId
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
    var fromPlanSetId: UUID?
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
        fromPlanSetId: UUID?,
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
        self.fromPlanSetId = fromPlanSetId
        self.targetWeightValue = targetWeightValue
        self.targetWeightUnitRaw = targetWeightUnitRaw
        self.targetReps = targetReps
    }
}

// MARK: - Mapper

extension WorkoutModel {
    /// 就地覆寫場次本身的欄位（不含 sets——那是 repository 的 diff 負責的）。
    /// 只有真的不同才賦值：SwiftData 對任何一次 setter 都會把該物件標成 dirty，
    /// 無條件寫十個欄位等於每次 save 都謊報整列有變。
    func applyScalars(from workout: Workout) {
        let day = workout.day.isoString
        if self.day != day { self.day = day }
        if planWorkoutId != workout.planWorkoutId { planWorkoutId = workout.planWorkoutId }
        if startedAt != workout.startedAt { startedAt = workout.startedAt }
        if endedAt != workout.endedAt { endedAt = workout.endedAt }
        if overallFeeling != workout.overallFeeling { overallFeeling = workout.overallFeeling }
        if note != workout.note { note = workout.note }
    }

    convenience init(from workout: Workout) {
        self.init(
            id: workout.id,
            day: workout.day.isoString,
            planWorkoutId: workout.planWorkoutId,
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
            planWorkoutId: planWorkoutId,
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
    /// 就地覆寫一組的欄位（`id` 與 `workout` 關聯不動——同一列就地更新才是 diff 的重點）。
    /// 同 `WorkoutModel.applyScalars`：只有真的不同才賦值。
    func apply(_ set: WorkoutSet) {
        if exerciseId != set.exerciseId { exerciseId = set.exerciseId }
        if exerciseIndex != set.exerciseIndex { exerciseIndex = set.exerciseIndex }
        if setIndex != set.setIndex { setIndex = set.setIndex }
        if weightValue != set.weight.value { weightValue = set.weight.value }
        let unitRaw = set.weight.unit.rawValue
        if weightUnitRaw != unitRaw { weightUnitRaw = unitRaw }
        if reps != set.reps { reps = set.reps }
        let status = set.status.rawValue
        if statusRaw != status { statusRaw = status }
        if fromPlanSetId != set.fromPlanSetId { fromPlanSetId = set.fromPlanSetId }
        if targetWeightValue != set.targetWeight?.value { targetWeightValue = set.targetWeight?.value }
        let targetUnitRaw = set.targetWeight?.unit.rawValue
        if targetWeightUnitRaw != targetUnitRaw { targetWeightUnitRaw = targetUnitRaw }
        if targetReps != set.targetReps { targetReps = set.targetReps }
    }

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
            fromPlanSetId: set.fromPlanSetId,
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
            fromPlanSetId: fromPlanSetId,
            targetWeight: targetWeightValue.map {
                Weight(value: $0, unit: WeightUnit(rawValue: targetWeightUnitRaw ?? "kg") ?? .kg)
            },
            targetReps: targetReps
        )
    }
}
