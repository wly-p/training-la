import Foundation
import Observation
import PlanDomain
import SharedKernel

@MainActor
@Observable
public final class PlanScheduleViewModel {
    public private(set) var planWorkouts: [PlanWorkout] = []
    public private(set) var templates: [WorkoutTemplate] = []
    public private(set) var catalog: [PlanCatalogExercise] = []
    /// 月曆上目前選取的日期（預設今天）。
    public var selectedDate: DayDate
    /// 本地化錯誤字串（延後解析，由 View 依 Environment locale 顯示）。
    public private(set) var errorMessage: LocalizedStringResource?

    private let listPlanWorkouts: ListPlanWorkouts
    private let createPlanWorkout: CreatePlanWorkout
    private let updatePlanWorkout: UpdatePlanWorkout
    private let deletePlanWorkout: DeletePlanWorkout
    private let listTemplates: ListTemplates
    private let instantiateTemplate: InstantiateTemplate
    private let exerciseCatalog: any PlanExerciseCatalog

    public init(
        listPlanWorkouts: ListPlanWorkouts,
        createPlanWorkout: CreatePlanWorkout,
        updatePlanWorkout: UpdatePlanWorkout,
        deletePlanWorkout: DeletePlanWorkout,
        listTemplates: ListTemplates,
        instantiateTemplate: InstantiateTemplate,
        exerciseCatalog: any PlanExerciseCatalog,
        today: @Sendable () -> DayDate = { DayDate(Date()) }
    ) {
        self.listPlanWorkouts = listPlanWorkouts
        self.createPlanWorkout = createPlanWorkout
        self.updatePlanWorkout = updatePlanWorkout
        self.deletePlanWorkout = deletePlanWorkout
        self.listTemplates = listTemplates
        self.instantiateTemplate = instantiateTemplate
        self.exerciseCatalog = exerciseCatalog
        self.selectedDate = today()
    }

    /// 某天的排課（依 orderIndex）。
    public func workouts(on date: DayDate) -> [PlanWorkout] {
        planWorkouts.filter { $0.date == date }.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// 有排課的日子（月曆畫點用）。
    public var markedDates: Set<DayDate> {
        Set(planWorkouts.map(\.date))
    }

    /// 某天的月曆標記：全部完成＝done，否則 scheduled；無排課＝nil。
    public func mark(on date: DayDate) -> DayMark? {
        let items = planWorkouts.filter { $0.date == date }
        guard !items.isEmpty else { return nil }
        return items.allSatisfy { $0.status == .done } ? .done : .scheduled
    }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    public func load() async {
        do {
            planWorkouts = try await listPlanWorkouts()
            templates = try await listTemplates()
            catalog = try await exerciseCatalog.exercises()
            errorMessage = nil
        } catch {
            errorMessage = .plan("plan.error.loadFailed \(error.localizedDescription)")
        }
    }

    public func create(name: String?, date: DayDate, drafts: [ExerciseTargetDraft]) async {
        await run { try await self.createPlanWorkout(name: name, date: date, drafts: drafts) }
    }

    public func update(id: UUID, name: String?, date: DayDate, drafts: [ExerciseTargetDraft]) async {
        await run { try await self.updatePlanWorkout(id: id, name: name, date: date, drafts: drafts) }
    }

    /// 從範本建一張排課到指定日期。
    public func addFromTemplate(templateId: UUID, on date: DayDate) async {
        await run { _ = try await self.instantiateTemplate(templateId: templateId, date: date) }
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
            errorMessage = .plan("plan.error.needExercise")
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
        }
    }
}
