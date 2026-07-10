import Foundation
import SharedKernel

/// 訓練紀錄的儲存介面。寫入一律整棵樹 upsert（對齊 API 的 aggregate 寫入模型）。
public protocol WorkoutRepository: Sendable {
    /// 整包寫入/取代（含全部 sets）。
    func save(_ workout: Workout) async throws
    func get(id: UUID) async throws -> Workout?
    func delete(id: UUID) async throws
    /// 進行中的場次（endedAt == nil，取最近開始的一筆）；App 重啟後靠這個恢復。
    func activeWorkout() async throws -> Workout?
    /// 某動作最近一次「已完成場次」的所有組（給記錄畫面的「上次」提示）。
    /// `excludingWorkout`：排除進行中的場次自己。
    func lastPerformance(exerciseId: UUID, excludingWorkout: UUID?) async throws -> [WorkoutSet]
    /// 全部已完成場次（day 新到舊；給歷史頁）。
    func finishedWorkouts() async throws -> [Workout]
    /// 某動作跨所有已完成場次的每一組（新到舊；本地版的 /v1/workout-sets?exercise_id=）。
    func exerciseHistory(exerciseId: UUID) async throws -> [ExerciseSetRecord]
    /// 有沒有任何一組紀錄引用這個動作（給刪動作的 in_use 檢查）。
    func usesExercise(_ exerciseId: UUID) async throws -> Bool
}

/// 動作歷史的一列：一組實際紀錄＋所屬場次的日期。
public struct ExerciseSetRecord: Equatable, Sendable {
    public let workoutId: UUID
    public let day: DayDate
    public let set: WorkoutSet

    public init(workoutId: UUID, day: DayDate, set: WorkoutSet) {
        self.workoutId = workoutId
        self.day = day
        self.set = set
    }
}

public enum WorkoutRepositoryError: Error, Equatable, Sendable {
    case notFound(id: UUID)
}
