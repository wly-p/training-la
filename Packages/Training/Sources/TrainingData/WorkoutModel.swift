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
    /// 追蹤模式（見 SetMeasurementCoding）。宣告時給預設值＝舊資料走輕量遷移。
    var modeRaw: String = TrackingMode.weightReps.rawValue
    var weightValue: Double
    var weightUnitRaw: String
    var reps: Int
    var durationSec: Int?
    var distanceM: Double?
    var statusRaw: String
    var fromPlanSetId: UUID?
    var targetModeRaw: String = TrackingMode.weightReps.rawValue
    var targetWeightValue: Double?
    var targetWeightUnitRaw: String?
    var targetReps: Int?
    var targetDurationSec: Int?
    var targetDistanceM: Double?
    /// 熱身組；宣告時給預設值＝舊資料走 SwiftData 輕量遷移（同 PlanWorkoutModel.originRaw 的作法）。
    var isWarmup: Bool = false
    var workout: WorkoutModel?

    init(
        id: UUID,
        exerciseId: UUID,
        exerciseIndex: Int,
        setIndex: Int,
        modeRaw: String,
        weightValue: Double,
        weightUnitRaw: String,
        reps: Int,
        durationSec: Int?,
        distanceM: Double?,
        statusRaw: String,
        fromPlanSetId: UUID?,
        targetModeRaw: String,
        targetWeightValue: Double?,
        targetWeightUnitRaw: String?,
        targetReps: Int?,
        targetDurationSec: Int?,
        targetDistanceM: Double?,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.modeRaw = modeRaw
        self.weightValue = weightValue
        self.weightUnitRaw = weightUnitRaw
        self.reps = reps
        self.durationSec = durationSec
        self.distanceM = distanceM
        self.statusRaw = statusRaw
        self.fromPlanSetId = fromPlanSetId
        self.targetModeRaw = targetModeRaw
        self.targetWeightValue = targetWeightValue
        self.targetWeightUnitRaw = targetWeightUnitRaw
        self.targetReps = targetReps
        self.targetDurationSec = targetDurationSec
        self.targetDistanceM = targetDistanceM
        self.isWarmup = isWarmup
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

        let m = SetMeasurementCoding.encode(set.measurement)
        if modeRaw != m.modeRaw { modeRaw = m.modeRaw }
        if weightValue != m.weightValue { weightValue = m.weightValue }
        if weightUnitRaw != m.weightUnitRaw { weightUnitRaw = m.weightUnitRaw }
        if reps != m.reps { reps = m.reps }
        if durationSec != m.durationSec { durationSec = m.durationSec }
        if distanceM != m.distanceM { distanceM = m.distanceM }

        let status = set.status.rawValue
        if statusRaw != status { statusRaw = status }
        if fromPlanSetId != set.fromPlanSetId { fromPlanSetId = set.fromPlanSetId }

        let t = set.targetMeasurement.map(SetMeasurementCoding.encode)
        let targetMode = t?.modeRaw ?? TrackingMode.weightReps.rawValue
        if targetModeRaw != targetMode { targetModeRaw = targetMode }
        if targetWeightValue != t?.weightValue { targetWeightValue = t?.weightValue }
        if targetWeightUnitRaw != t?.weightUnitRaw { targetWeightUnitRaw = t?.weightUnitRaw }
        if targetReps != t?.reps { targetReps = t?.reps }
        if targetDurationSec != t?.durationSec { targetDurationSec = t?.durationSec }
        if targetDistanceM != t?.distanceM { targetDistanceM = t?.distanceM }

        if isWarmup != set.isWarmup { isWarmup = set.isWarmup }
    }

    convenience init(from set: WorkoutSet) {
        let m = SetMeasurementCoding.encode(set.measurement)
        let t = set.targetMeasurement.map(SetMeasurementCoding.encode)
        self.init(
            id: set.id,
            exerciseId: set.exerciseId,
            exerciseIndex: set.exerciseIndex,
            setIndex: set.setIndex,
            modeRaw: m.modeRaw,
            weightValue: m.weightValue,
            weightUnitRaw: m.weightUnitRaw,
            reps: m.reps,
            durationSec: m.durationSec,
            distanceM: m.distanceM,
            statusRaw: set.status.rawValue,
            fromPlanSetId: set.fromPlanSetId,
            targetModeRaw: t?.modeRaw ?? TrackingMode.weightReps.rawValue,
            targetWeightValue: t?.weightValue,
            targetWeightUnitRaw: t?.weightUnitRaw,
            targetReps: t?.reps,
            targetDurationSec: t?.durationSec,
            targetDistanceM: t?.distanceM,
            isWarmup: set.isWarmup
        )
    }

    func toDomain() -> WorkoutSet {
        // 目標快照：只有「真的有目標」時才組出來。判定沿用舊語意——
        // 舊資料的目標是 targetWeightValue ＋ targetReps，兩者皆 nil＝臨時加練沒有目標。
        let hasTarget = targetWeightValue != nil || targetReps != nil
            || targetDurationSec != nil || targetDistanceM != nil
        return WorkoutSet(
            id: id,
            exerciseId: exerciseId,
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            measurement: SetMeasurementCoding.decode(
                modeRaw: modeRaw, weightValue: weightValue, weightUnitRaw: weightUnitRaw,
                reps: reps, durationSec: durationSec, distanceM: distanceM
            ),
            status: WorkoutSetStatus(rawValue: statusRaw) ?? .done,
            fromPlanSetId: fromPlanSetId,
            targetMeasurement: hasTarget ? SetMeasurementCoding.decode(
                modeRaw: targetModeRaw,
                weightValue: targetWeightValue ?? 0,
                weightUnitRaw: targetWeightUnitRaw ?? WeightUnit.kg.rawValue,
                reps: targetReps ?? 0,
                durationSec: targetDurationSec, distanceM: targetDistanceM
            ) : nil,
            isWarmup: isWarmup
        )
    }
}
