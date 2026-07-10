import SwiftData
import TrainingDomain

/// Composition Root 組裝入口；schema 由 App 層彙總各 domain 的 `models`。
public enum TrainingDataFactory {
    public static var models: [any PersistentModel.Type] { [WorkoutModel.self, WorkoutSetModel.self] }

    public static func makeWorkoutRepository(container: ModelContainer) -> any WorkoutRepository {
        SwiftDataWorkoutRepository(modelContainer: container)
    }
}
