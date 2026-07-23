import Foundation
import PlanDomain
import SwiftData

@ModelActor
public actor SwiftDataRotationRepository: RotationRepository {
    /// 單一 active 循環：固定 id 的 singleton row。
    private static let singletonID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    public func load() async throws -> Rotation {
        try fetchModel()?.toDomain() ?? Rotation()
    }

    public func save(_ rotation: Rotation) async throws {
        if let existing = try fetchModel() {
            modelContext.delete(existing)
        }
        let model = RotationModel(id: Self.singletonID, cursor: rotation.cursor)
        model.workouts = rotation.workouts.enumerated().map { index, spec in
            RotationWorkoutModel(from: spec, orderIndex: index)
        }
        modelContext.insert(model)
        try modelContext.save()
    }

    public func usesExercise(_ exerciseId: UUID) async throws -> Bool {
        var descriptor = FetchDescriptor<RotationSetModel>(
            predicate: #Predicate { $0.exerciseId == exerciseId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first != nil
    }

    private func fetchModel() throws -> RotationModel? {
        var descriptor = FetchDescriptor<RotationModel>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
