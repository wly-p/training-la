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
    /// 器材決定重量遞增最小單位（`Equipment.weightStep`）——投影收斂「相對上次」時取整用。
    public let equipment: Equipment

    public init(id: UUID, name: String, muscleGroup: MuscleGroup, equipment: Equipment) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
    }
}
