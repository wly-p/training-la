import Foundation
import SharedKernel

/// 歷史紀錄的編輯／刪除 port。與唯讀的 [WorkoutHistoryReading] 分離：
/// 由 App adapter 接到 Training 的 WorkoutRepository（整包 upsert / 刪除）。
/// History 因此不 import Training，只認識自己的顯示／編輯型別。
public protocol WorkoutHistoryEditing: Sendable {
    /// 刪除整場紀錄。
    func deleteWorkout(id: UUID) async throws
    /// 更新場次內各組的重量／次數／狀態（其餘結構——組數、動作、順序——不動）。
    /// 採整包更新：adapter 讀回 aggregate、套用 edits、整棵樹重存。
    func updateSets(workoutId: UUID, edits: [HistorySetEdit]) async throws
}

/// 一組的可編輯欄位。以 set id 對回原紀錄。
public struct HistorySetEdit: Equatable, Sendable {
    public let id: UUID
    public let weight: Weight
    public let reps: Int
    public let status: WorkoutSetStatus

    public init(id: UUID, weight: Weight, reps: Int, status: WorkoutSetStatus) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.status = status
    }
}
