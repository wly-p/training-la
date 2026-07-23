import Foundation

/// 環尋循環的儲存（MVP 為單一 active 循環，singleton）。
public protocol RotationRepository: Sendable {
    /// 讀出目前循環；沒設定過＝空循環。
    func load() async throws -> Rotation
    /// 整包寫入。
    func save(_ rotation: Rotation) async throws
    /// 有沒有任何一組循環 workout 引用這個動作（給刪動作的 in_use 檢查）。
    func usesExercise(_ exerciseId: UUID) async throws -> Bool
}
