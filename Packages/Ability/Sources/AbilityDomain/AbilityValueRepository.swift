import Foundation

public protocol AbilityValueRepository: Sendable {
    /// 全部能力值（給「我的能力值」清單）。
    func all() async throws -> [AbilityValue]
    func get(exerciseId: UUID) async throws -> AbilityValue?
    /// 整包寫入/取代（以 exerciseId upsert）。
    func save(_ value: AbilityValue) async throws
    func delete(exerciseId: UUID) async throws
}
