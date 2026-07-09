import Foundation
import SharedKernel

/// Training 對「動作庫」的 port：只描述自己需要什麼，不 import Spec。
/// 由 App（Composition Root）用 Spec domain 的 use case 實作接上。
public protocol ExerciseCatalog: Sendable {
    func exercises() async throws -> [CatalogExercise]
}

public struct CatalogExercise: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let muscleGroup: MuscleGroup

    public init(id: UUID, name: String, muscleGroup: MuscleGroup) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
    }
}
