import Foundation

/// 循環課表的儲存（可多組並行）。
public protocol RotationRepository: Sendable {
    /// 全部循環，依 orderIndex 升序。
    func all() async throws -> [Rotation]
    func get(id: UUID) async throws -> Rotation?
    /// 整包寫入/取代（以 id upsert）。
    func save(_ rotation: Rotation) async throws
    func delete(id: UUID) async throws
    /// 有沒有任何一組循環 workout 引用這個動作（給刪動作的 in_use 檢查）。
    func usesExercise(_ exerciseId: UUID) async throws -> Bool
}

public enum RotationRepositoryError: Error, Equatable, Sendable {
    case notFound(id: UUID)
}
