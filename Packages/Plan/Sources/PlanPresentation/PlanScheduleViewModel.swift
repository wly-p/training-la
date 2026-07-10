import Foundation
import Observation
import PlanDomain
import SharedKernel

@MainActor
@Observable
public final class PlanScheduleViewModel {
    public private(set) var planWorkouts: [PlanWorkout] = []
    public private(set) var catalog: [PlanCatalogExercise] = []
    public private(set) var errorMessage: String?

    private let listPlanWorkouts: ListPlanWorkouts
    private let createPlanWorkout: CreatePlanWorkout
    private let updatePlanWorkout: UpdatePlanWorkout
    private let deletePlanWorkout: DeletePlanWorkout
    private let exerciseCatalog: any PlanExerciseCatalog

    public init(
        listPlanWorkouts: ListPlanWorkouts,
        createPlanWorkout: CreatePlanWorkout,
        updatePlanWorkout: UpdatePlanWorkout,
        deletePlanWorkout: DeletePlanWorkout,
        exerciseCatalog: any PlanExerciseCatalog
    ) {
        self.listPlanWorkouts = listPlanWorkouts
        self.createPlanWorkout = createPlanWorkout
        self.updatePlanWorkout = updatePlanWorkout
        self.deletePlanWorkout = deletePlanWorkout
        self.exerciseCatalog = exerciseCatalog
    }

    public var datedWorkouts: [PlanWorkout] {
        planWorkouts.filter { !$0.isCycle }.sorted { ($0.date!, $0.orderIndex) < ($1.date!, $1.orderIndex) }
    }

    public var cycleWorkouts: [PlanWorkout] {
        planWorkouts.filter { $0.isCycle }.sorted { $0.orderIndex < $1.orderIndex }
    }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    public func load() async {
        do {
            planWorkouts = try await listPlanWorkouts()
            catalog = try await exerciseCatalog.exercises()
            errorMessage = nil
        } catch {
            errorMessage = "讀取課表失敗：\(error.localizedDescription)"
        }
    }

    public func create(name: String?, date: DayDate?, drafts: [ExerciseTargetDraft]) async {
        await run { try await self.createPlanWorkout(name: name, date: date, drafts: drafts) }
    }

    public func update(id: UUID, name: String?, date: DayDate?, drafts: [ExerciseTargetDraft]) async {
        await run { try await self.updatePlanWorkout(id: id, name: name, date: date, drafts: drafts) }
    }

    public func delete(id: UUID) async {
        await run { try await self.deletePlanWorkout(id: id) }
    }

    public func dismissError() { errorMessage = nil }

    private func run(_ operation: @escaping () async throws -> Void) async {
        do {
            try await operation()
            await load()
        } catch PlanWorkoutValidationError.empty {
            errorMessage = "排課至少要有一個動作"
        } catch {
            errorMessage = "操作失敗：\(error.localizedDescription)"
        }
    }
}
