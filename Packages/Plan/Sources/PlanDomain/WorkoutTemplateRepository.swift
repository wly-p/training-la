import Foundation

public protocol WorkoutTemplateRepository: Sendable {
    /// 全部範本，依 orderIndex 升序。
    func all() async throws -> [WorkoutTemplate]
    func get(id: UUID) async throws -> WorkoutTemplate?
    /// 整包寫入/取代。
    func save(_ template: WorkoutTemplate) async throws
    func delete(id: UUID) async throws
    /// 有沒有任何一組範本目標引用這個動作（給刪動作的 in_use 檢查）。
    func usesExercise(_ exerciseId: UUID) async throws -> Bool
}

public enum WorkoutTemplateRepositoryError: Error, Equatable, Sendable {
    case notFound(id: UUID)
}
