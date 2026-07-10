import Foundation

/// 歷史資料的讀取 port。由 App adapter 用 Training 的紀錄 ＋ Spec 的動作名稱組出來；
/// History 因此不 import Training / Spec，只認識自己的顯示型別。
public protocol WorkoutHistoryReading: Sendable {
    /// 按日期：所有已完成場次（新到舊）。
    func workouts() async throws -> [HistoryWorkoutSummary]
    /// 單一場次詳情。
    func workoutDetail(id: UUID) async throws -> HistoryWorkoutDetail?
    /// 按動作：有歷史紀錄的動作（依名稱排序）。
    func exercisesWithHistory() async throws -> [HistoryExerciseOption]
    /// 某動作的歷次場次（新到舊，一場一列）。
    func sessions(exerciseId: UUID) async throws -> [HistoryExerciseSession]
}
