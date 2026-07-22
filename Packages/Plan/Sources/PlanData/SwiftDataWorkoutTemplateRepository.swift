import Foundation
import PlanDomain
import SwiftData

@ModelActor
public actor SwiftDataWorkoutTemplateRepository: WorkoutTemplateRepository {
    public func all() async throws -> [WorkoutTemplate] {
        let descriptor = FetchDescriptor<WorkoutTemplateModel>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func get(id: UUID) async throws -> WorkoutTemplate? {
        try fetchModel(id: id)?.toDomain()
    }

    public func save(_ template: WorkoutTemplate) async throws {
        if let existing = try fetchModel(id: template.id) {
            modelContext.delete(existing)
        }
        modelContext.insert(WorkoutTemplateModel(from: template))
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        guard let model = try fetchModel(id: id) else {
            throw WorkoutTemplateRepositoryError.notFound(id: id)
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    public func usesExercise(_ exerciseId: UUID) async throws -> Bool {
        var descriptor = FetchDescriptor<TemplateSetModel>(
            predicate: #Predicate { $0.exerciseId == exerciseId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first != nil
    }

    private func fetchModel(id: UUID) throws -> WorkoutTemplateModel? {
        var descriptor = FetchDescriptor<WorkoutTemplateModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
