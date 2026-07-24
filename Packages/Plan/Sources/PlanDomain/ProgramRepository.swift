import Foundation

/// 多週長期課表定義的儲存。
public protocol ProgramRepository: Sendable {
    /// 全部課表，依 orderIndex 升序。
    func all() async throws -> [Program]
    func get(id: UUID) async throws -> Program?
    /// 整包寫入/取代（以 id upsert）。
    func save(_ program: Program) async throws
    func delete(id: UUID) async throws
    /// 有沒有任何一格課表的 workout 引用這個動作（給刪動作的 in_use 檢查）。
    func usesExercise(_ exerciseId: UUID) async throws -> Bool
}

/// 套用紀錄（哪份課表、從哪天起、跑一次或重複）的儲存。
public protocol ProgramAssignmentRepository: Sendable {
    func all() async throws -> [ProgramAssignment]
    func get(id: UUID) async throws -> ProgramAssignment?
    func save(_ assignment: ProgramAssignment) async throws
    func delete(id: UUID) async throws
    /// 引用某份課表的所有套用（刪課表時一併處理）。
    func forProgram(_ programId: UUID) async throws -> [ProgramAssignment]
}

public enum ProgramRepositoryError: Error, Equatable, Sendable {
    case notFound(id: UUID)
}
