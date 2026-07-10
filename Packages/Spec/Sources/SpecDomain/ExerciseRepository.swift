import Foundation
import SharedKernel

/// 動作庫的儲存介面。Data 層提供實作；上層一律只依賴此 protocol。
public protocol ExerciseRepository: Sendable {
    /// 列出動作，依名稱排序；`muscleGroup` 非 nil 時過濾。
    func list(muscleGroup: MuscleGroup?) async throws -> [Exercise]
    func get(id: UUID) async throws -> Exercise?
    func create(_ exercise: Exercise) async throws
    func update(_ exercise: Exercise) async throws
    func delete(id: UUID) async throws
}

public enum ExerciseRepositoryError: Error, Equatable, Sendable {
    case notFound(id: UUID)
    /// 動作被課表 / 訓練紀錄引用，無法刪除（對齊 API 契約的 `in_use`）。
    case inUse(id: UUID)
}

/// 「這個動作有沒有被引用」的查詢 port。
/// 本地由 App 接到 Training / Plan 的資料落實；未來走 API 時改由伺服器的 409 落實，此 port 不再被 wire。
public protocol ExerciseUsageChecking: Sendable {
    func isUsed(exerciseId: UUID) async throws -> Bool
}
