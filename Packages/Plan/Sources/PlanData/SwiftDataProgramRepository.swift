import Foundation
import PlanDomain
import SwiftData

@ModelActor
public actor SwiftDataProgramRepository: ProgramRepository {
    public func all() async throws -> [Program] {
        let descriptor = FetchDescriptor<ProgramModel>(sortBy: [SortDescriptor(\.orderIndex)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func get(id: UUID) async throws -> Program? {
        try fetchModel(id: id)?.toDomain()
    }

    public func save(_ program: Program) async throws {
        if let existing = try fetchModel(id: program.id) {
            modelContext.delete(existing)
        }
        modelContext.insert(ProgramModel(from: program))
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        guard let model = try fetchModel(id: id) else {
            throw ProgramRepositoryError.notFound(id: id)
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    public func usesExercise(_ exerciseId: UUID) async throws -> Bool {
        var descriptor = FetchDescriptor<ProgramSlotSetModel>(
            predicate: #Predicate { $0.exerciseId == exerciseId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first != nil
    }

    private func fetchModel(id: UUID) throws -> ProgramModel? {
        var descriptor = FetchDescriptor<ProgramModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}

@ModelActor
public actor SwiftDataProgramAssignmentRepository: ProgramAssignmentRepository {
    public func all() async throws -> [ProgramAssignment] {
        try modelContext.fetch(FetchDescriptor<ProgramAssignmentModel>()).map { $0.toDomain() }
    }

    public func get(id: UUID) async throws -> ProgramAssignment? {
        try fetchModel(id: id)?.toDomain()
    }

    public func save(_ assignment: ProgramAssignment) async throws {
        if let existing = try fetchModel(id: assignment.id) {
            modelContext.delete(existing)
        }
        modelContext.insert(ProgramAssignmentModel(from: assignment))
        try modelContext.save()
    }

    public func delete(id: UUID) async throws {
        guard let model = try fetchModel(id: id) else {
            throw ProgramRepositoryError.notFound(id: id)
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    public func forProgram(_ programId: UUID) async throws -> [ProgramAssignment] {
        let descriptor = FetchDescriptor<ProgramAssignmentModel>(
            predicate: #Predicate { $0.programId == programId }
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    private func fetchModel(id: UUID) throws -> ProgramAssignmentModel? {
        var descriptor = FetchDescriptor<ProgramAssignmentModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
