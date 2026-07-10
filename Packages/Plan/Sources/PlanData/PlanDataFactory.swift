import PlanDomain
import SwiftData

public enum PlanDataFactory {
    public static var models: [any PersistentModel.Type] { [PlanWorkoutModel.self, PlanSetModel.self] }

    public static func makePlanWorkoutRepository(container: ModelContainer) -> any PlanWorkoutRepository {
        SwiftDataPlanWorkoutRepository(modelContainer: container)
    }
}
