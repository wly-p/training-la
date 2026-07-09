import Foundation
import SharedKernel

/// 歷史頁的顯示用值物件。名稱等資料已在 App adapter 解析好，Presentation 只負責畫。

/// 「按日期」列表的一列。
public struct HistoryWorkoutSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let day: DayDate
    public let exerciseCount: Int
    public let totalSets: Int
    public let overallFeeling: Int?
    public let durationMinutes: Int?

    public init(
        id: UUID,
        day: DayDate,
        exerciseCount: Int,
        totalSets: Int,
        overallFeeling: Int?,
        durationMinutes: Int?
    ) {
        self.id = id
        self.day = day
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
    public let sets: [HistorySetLine]

    public init(id: Int, exerciseName: String, sets: [HistorySetLine]) {
        self.id = id
        self.exerciseName = exerciseName
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

    public init(id: UUID, name: String, muscleGroup: MuscleGroup) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
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
