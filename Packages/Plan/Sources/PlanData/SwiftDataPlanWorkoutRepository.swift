import Foundation
import PlanDomain
import SharedKernel
import SwiftData

@ModelActor
public actor SwiftDataPlanWorkoutRepository: PlanWorkoutRepository {
    public func all() async throws -> [PlanWorkout] {
        let descriptor = FetchDescriptor<PlanWorkoutModel>(
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func get(id: UUID) async throws -> PlanWorkout? {
        try fetchModel(id: id)?.toDomain()
    }

    public func save(_ planWorkout: PlanWorkout) async throws {
        if let existing = try fetchModel(id: planWorkout.id) {
            modelContext.delete(existing)
        }
        modelContext.insert(PlanWorkoutModel(from: planWorkout))
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        guard let model = try fetchModel(id: id) else {
            throw PlanWorkoutRepositoryError.notFound(id: id)
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    public func onDate(_ day: DayDate) async throws -> [PlanWorkout] {
        let iso = day.isoString
        let descriptor = FetchDescriptor<PlanWorkoutModel>(
            predicate: #Predicate { $0.date == iso },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func cycle() async throws -> [PlanWorkout] {
        let descriptor = FetchDescriptor<PlanWorkoutModel>(
            predicate: #Predicate { $0.date == nil },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func usesExercise(_ exerciseId: UUID) async throws -> Bool {
        var descriptor = FetchDescriptor<PlanSetModel>(
            predicate: #Predicate { $0.exerciseId == exerciseId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first != nil
    }

    private func fetchModel(id: UUID) throws -> PlanWorkoutModel? {
        var descriptor = FetchDescriptor<PlanWorkoutModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
