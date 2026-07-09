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
}

public enum WorkoutRepositoryError: Error, Equatable, Sendable {
    case notFound(id: UUID)
}
