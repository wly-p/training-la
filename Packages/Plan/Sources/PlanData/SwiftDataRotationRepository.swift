import Foundation
import PlanDomain
import SwiftData

@ModelActor
public actor SwiftDataRotationRepository: RotationRepository {
    public func all() async throws -> [Rotation] {
        let descriptor = FetchDescriptor<RotationModel>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func get(id: UUID) async throws -> Rotation? {
        try fetchModel(id: id)?.toDomain()
    }

    public func save(_ rotation: Rotation) async throws {
        if let existing = try fetchModel(id: rotation.id) {
            modelContext.delete(existing)
        }
        modelContext.insert(RotationModel(from: rotation))
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        guard let model = try fetchModel(id: id) else {
            throw RotationRepositoryError.notFound(id: id)
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    public func usesExercise(_ exerciseId: UUID) async throws -> Bool {
        var descriptor = FetchDescriptor<RotationSetModel>(
            predicate: #Predicate { $0.exerciseId == exerciseId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first != nil
    }

    private func fetchModel(id: UUID) throws -> RotationModel? {
        var descriptor = FetchDescriptor<RotationModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
