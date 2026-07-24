import PlanDomain
import SwiftData

public enum PlanDataFactory {
    public static var models: [any PersistentModel.Type] {
        [
            PlanWorkoutModel.self, PlanSetModel.self,
            WorkoutTemplateModel.self, TemplateSetModel.self,
            RotationModel.self, RotationWorkoutModel.self, RotationSetModel.self,
            ProgramModel.self, ProgramSlotModel.self, ProgramSlotSetModel.self,
            ProgramAssignmentModel.self,
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

    public static func makeProgramRepository(container: ModelContainer) -> any ProgramRepository {
        SwiftDataProgramRepository(modelContainer: container)
    }

    public static func makeProgramAssignmentRepository(container: ModelContainer) -> any ProgramAssignmentRepository {
        SwiftDataProgramAssignmentRepository(modelContainer: container)
    }
}
