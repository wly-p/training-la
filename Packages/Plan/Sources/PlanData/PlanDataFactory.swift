import PlanDomain
import SwiftData

public enum PlanDataFactory {
    public static var models: [any PersistentModel.Type] {
        [
            PlanWorkoutModel.self, PlanSetModel.self,
            WorkoutTemplateModel.self, TemplateSetModel.self,
            RotationModel.self, RotationWorkoutModel.self, RotationSetModel.self,
        ]
    }

    public static func makePlanWorkoutRepository(container: ModelContainer) -> any PlanWorkoutRepository {
        SwiftDataPlanWorkoutRepository(modelContainer: container)
    }

    public static func makeWorkoutTemplateRepository(container: ModelContainer) -> any WorkoutTemplateRepository {
        SwiftDataWorkoutTemplateRepository(modelContainer: container)
    }

    public static func makeRotationRepository(container: ModelContainer) -> any RotationRepository {
        SwiftDataRotationRepository(modelContainer: container)
    }
}
