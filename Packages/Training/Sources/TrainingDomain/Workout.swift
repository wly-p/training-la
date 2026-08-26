import Foundation
import SharedKernel

/// 一次訓練場次（aggregate root）。結構對齊 API 契約的 Workout → WorkoutSet：
/// 整棵樹一起寫入/取代，之後接後端就是整包上傳的單位。
public struct Workout: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var day: DayDate
    /// 照哪個排課做；nil＝自由訓練。
    public var planWorkoutId: UUID?
    public var startedAt: Date?
    public var endedAt: Date?
    /// 1–5；結束訓練時才填。
    public var overallFeeling: Int?
    public var note: String?
    /// 依 (exerciseIndex, setIndex) 排序。
    public var sets: [WorkoutSet]

    public init(
        id: UUID,
        day: DayDate,
        planWorkoutId: UUID? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        overallFeeling: Int? = nil,
        note: String? = nil,
        sets: [WorkoutSet] = []
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

    public var isFinished: Bool { endedAt != nil }
}

/// 場次內的一組。exerciseIndex 相同＝同一個動作區塊；index 皆 0-based，由 app 指派。
public struct WorkoutSet: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var exerciseId: UUID
    public var exerciseIndex: Int
    public var setIndex: Int
    /// 這一組實際做了什麼。取代原本並排的 `weight` ＋ `reps`——
    /// 型別上就不可能組出「時間模式卻帶重量」，見 `SetMeasurement`。
    public var measurement: SetMeasurement
    public var status: WorkoutSetStatus
    /// 照課表哪一組做的；nil＝臨時加練。
    public var fromPlanSetId: UUID?
    /// 目標快照（完成當下複製；課表事後被改不影響已存紀錄）。
    public var targetMeasurement: SetMeasurement?
    /// 熱身組：仍然是一筆紀錄，但**不進任何統計**（總量、達標、PR、「上次」預填、能力值）。
    /// 熱身的 20kg 混進「上次」會讓下一場預填成 20kg，混進總量會讓進步曲線失真。
    public var isWarmup: Bool

    public init(
        id: UUID,
        exerciseId: UUID,
        exerciseIndex: Int,
        setIndex: Int,
        measurement: SetMeasurement,
        status: WorkoutSetStatus = .done,
        fromPlanSetId: UUID? = nil,
        targetMeasurement: SetMeasurement? = nil,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.measurement = measurement
        self.status = status
        self.fromPlanSetId = fromPlanSetId
        self.targetMeasurement = targetMeasurement
        self.isWarmup = isWarmup
    }
}

/// 同一動作的連續組（依 exerciseIndex 分組後的視圖）。
public struct ExerciseBlock: Identifiable, Equatable, Sendable {
    public let exerciseIndex: Int
    public let exerciseId: UUID
    public let sets: [WorkoutSet]

    public var id: Int { exerciseIndex }
}

extension Workout {
    /// 依 exerciseIndex 分組、組內依 setIndex 排序。
    public var blocks: [ExerciseBlock] {
        Dictionary(grouping: sets, by: \.exerciseIndex)
            .sorted { $0.key < $1.key }
            .map { index, sets in
                ExerciseBlock(
                    exerciseIndex: index,
                    exerciseId: sets[0].exerciseId,
                    sets: sets.sorted { $0.setIndex < $1.setIndex }
                )
            }
    }

    /// 記一組：該動作已有區塊就接在最後一個同動作區塊之後，否則開新區塊。
    /// index 指派規則集中在這裡，保證 (exerciseIndex, setIndex) 唯一且連續。
    /// 照課表做的組帶 `fromPlanSetId` ＋ `target*` 快照；臨時加練都留 nil。
    public mutating func appendSet(
        id: UUID = UUID(),
        exerciseId: UUID,
        measurement: SetMeasurement,
        status: WorkoutSetStatus = .done,
        fromPlanSetId: UUID? = nil,
        targetMeasurement: SetMeasurement? = nil,
        isWarmup: Bool = false
    ) {
        let exerciseIndex: Int
        let setIndex: Int
        if let block = blocks.last(where: { $0.exerciseId == exerciseId }) {
            exerciseIndex = block.exerciseIndex
            setIndex = (block.sets.map(\.setIndex).max() ?? -1) + 1
        } else {
            exerciseIndex = (sets.map(\.exerciseIndex).max() ?? -1) + 1
            setIndex = 0
        }
        sets.append(WorkoutSet(
            id: id,
            exerciseId: exerciseId,
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            measurement: measurement,
            status: status,
            fromPlanSetId: fromPlanSetId,
            targetMeasurement: targetMeasurement,
            isWarmup: isWarmup
        ))
        sets.sort { ($0.exerciseIndex, $0.setIndex) < ($1.exerciseIndex, $1.setIndex) }
    }

    /// 移除指定的一組（撤銷剛記錄的組用）。只用在移除某動作的「最後一組」，
    /// 因此不會在 setIndex 中間留洞，其餘各組維持連續、不需重編號。
    public mutating func removeSet(id: UUID) {
        sets.removeAll { $0.id == id }
    }
}
