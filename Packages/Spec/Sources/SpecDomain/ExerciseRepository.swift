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
}
