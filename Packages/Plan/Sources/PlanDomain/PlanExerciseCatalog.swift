import Foundation
import SharedKernel

/// Plan 對動作庫的 port（編輯排課時挑動作、顯示名稱）。由 App 接到 Spec。
public protocol PlanExerciseCatalog: Sendable {
    func exercises() async throws -> [PlanCatalogExercise]
}

public struct PlanCatalogExercise: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let muscleGroup: MuscleGroup

    public init(id: UUID, name: String, muscleGroup: MuscleGroup) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
    }
}
