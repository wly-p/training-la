import Foundation
import SharedKernel

/// 歷史頁的顯示用值物件。名稱等資料已在 App adapter 解析好，Presentation 只負責畫。

/// 「按日期」列表的一列。
public struct HistoryWorkoutSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let day: DayDate
    /// 照哪份排課做的名稱；nil＝自由訓練（沒有對應排課）。設計稿 7b 的列主標。
    public let name: String?
    public let exerciseCount: Int
    public let totalSets: Int
    public let overallFeeling: Int?
    public let durationMinutes: Int?

    public init(
        id: UUID,
        day: DayDate,
        name: String? = nil,
        exerciseCount: Int,
        totalSets: Int,
        overallFeeling: Int?,
        durationMinutes: Int?
    ) {
        self.id = id
        self.day = day
        self.name = name
        self.exerciseCount = exerciseCount
        self.totalSets = totalSets
        self.overallFeeling = overallFeeling
        self.durationMinutes = durationMinutes
    }
}

/// 場次詳情：summary ＋ 分動作的區塊。
public struct HistoryWorkoutDetail: Identifiable, Equatable, Sendable {
    public let summary: HistoryWorkoutSummary
    public let note: String?
    public let blocks: [HistoryBlock]

    public var id: UUID { summary.id }

    public init(summary: HistoryWorkoutSummary, note: String?, blocks: [HistoryBlock]) {
        self.summary = summary
        self.note = note
        self.blocks = blocks
    }
}

public struct HistoryBlock: Identifiable, Equatable, Sendable {
    public let id: Int          // exerciseIndex
    public let exerciseName: String
    /// 器材：逐組對照的分組標頭要顯示（動作名允許重複，靠它分辨）。
    public let equipment: Equipment
    public let sets: [HistorySetLine]

    public init(id: Int, exerciseName: String, equipment: Equipment = .other, sets: [HistorySetLine]) {
        self.id = id
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.sets = sets
    }
}

public struct HistorySetLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let setIndex: Int
    public let weight: Weight
    public let reps: Int
    public let status: WorkoutSetStatus
    public let targetWeight: Weight?
    public let targetReps: Int?

    public init(
        id: UUID,
        setIndex: Int,
        weight: Weight,
        reps: Int,
        status: WorkoutSetStatus,
        targetWeight: Weight?,
        targetReps: Int?
    ) {
        self.id = id
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.status = status
        self.targetWeight = targetWeight
        self.targetReps = targetReps
    }
}

/// 「按動作」的動作選項（只列出有歷史紀錄的動作）。
public struct HistoryExerciseOption: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let muscleGroup: MuscleGroup
    /// 器材：名稱允許重複，選動作看趨勢時靠它分辨（見 docs/exercise-glossary.md）。
    public let equipment: Equipment

    public init(id: UUID, name: String, muscleGroup: MuscleGroup, equipment: Equipment) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
    }
}

/// 「按動作」某一次場次做的組（依日期一列一場）。
public struct HistoryExerciseSession: Identifiable, Equatable, Sendable {
    public let id: UUID        // workoutId
    public let day: DayDate
    public let sets: [HistorySetLine]

    public init(id: UUID, day: DayDate, sets: [HistorySetLine]) {
        self.id = id
        self.day = day
        self.sets = sets
    }
}
