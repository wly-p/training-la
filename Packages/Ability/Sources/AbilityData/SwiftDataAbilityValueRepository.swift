import Foundation
import AbilityDomain
import SwiftData

@ModelActor
public actor SwiftDataAbilityValueRepository: AbilityValueRepository {
    public func all() async throws -> [AbilityValue] {
        let descriptor = FetchDescriptor<AbilityValueModel>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func get(exerciseId: UUID) async throws -> AbilityValue? {
        try fetchModel(exerciseId: exerciseId)?.toDomain()
    }

    public func save(_ value: AbilityValue) async throws {
        if let existing = try fetchModel(exerciseId: value.exerciseId) {
            modelContext.delete(existing)
        }
        modelContext.insert(AbilityValueModel(from: value))
        try modelContext.save()
    }

    public func delete(exerciseId: UUID) async throws {
        guard let model = try fetchModel(exerciseId: exerciseId) else { return }
        modelContext.delete(model)
        try modelContext.save()
    }

    private func fetchModel(exerciseId: UUID) throws -> AbilityValueModel? {
        var descriptor = FetchDescriptor<AbilityValueModel>(
            predicate: #Predicate { $0.exerciseId == exerciseId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
