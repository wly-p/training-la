import Foundation
import SharedKernel
import SpecDomain
import SwiftData

/// `ExerciseRepository` 的 SwiftData 實作。@ModelActor 保證所有存取都在自己的 executor 上。
@ModelActor
public actor SwiftDataExerciseRepository: ExerciseRepository {
    public func list(muscleGroup: MuscleGroup?) async throws -> [Exercise] {
        var descriptor = FetchDescriptor<ExerciseModel>(sortBy: [SortDescriptor(\.name)])
        if let muscleGroup {
            let raw = muscleGroup.rawValue
            descriptor.predicate = #Predicate { $0.muscleGroupRaw == raw }
        }
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func get(id: UUID) async throws -> Exercise? {
        try fetchModel(id: id)?.toDomain()
    }

    public func create(_ exercise: Exercise) async throws {
        modelContext.insert(ExerciseModel(from: exercise))
        try modelContext.save()
    }

    public func update(_ exercise: Exercise) async throws {
        guard let model = try fetchModel(id: exercise.id) else {
            throw ExerciseRepositoryError.notFound(id: exercise.id)
        }
        model.apply(exercise)
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        guard let model = try fetchModel(id: id) else {
            throw ExerciseRepositoryError.notFound(id: id)
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    private func fetchModel(id: UUID) throws -> ExerciseModel? {
        var descriptor = FetchDescriptor<ExerciseModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
