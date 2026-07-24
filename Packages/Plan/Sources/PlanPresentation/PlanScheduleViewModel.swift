import Foundation
import Observation
import PlanDomain
import SharedKernel

@MainActor
@Observable
public final class PlanScheduleViewModel {
    public private(set) var planWorkouts: [PlanWorkout] = []
    public private(set) var templates: [WorkoutTemplate] = []
    /// 可套用的長期課表（給「套用」sheet 的清單）。
    public private(set) var programs: [Program] = []
    /// 目前套用中的長期課表（給管理/停用）。
    public private(set) var assignments: [ProgramAssignment] = []
    /// 今天（含）以後的投影建議，依日期分組。
    public private(set) var projectionsByDate: [DayDate: [ProjectedWorkout]] = [:]
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
    private let listPrograms: ListPrograms
    private let listAssignments: ListProgramAssignments
    private let applyProgramUseCase: ApplyProgram
    private let deleteAssignmentUseCase: DeleteProgramAssignment
    private let reconcile: ReconcileProgramAssignments
    private let projectSchedule: ProjectSchedule
    private let materializeProjection: MaterializeProjectedWorkout
    private let exerciseCatalog: any PlanExerciseCatalog
    private let today: DayDate

    public init(
        listPlanWorkouts: ListPlanWorkouts,
        createPlanWorkout: CreatePlanWorkout,
        updatePlanWorkout: UpdatePlanWorkout,
        deletePlanWorkout: DeletePlanWorkout,
        listTemplates: ListTemplates,
        instantiateTemplate: InstantiateTemplate,
        listPrograms: ListPrograms,
        listAssignments: ListProgramAssignments,
        applyProgram: ApplyProgram,
        deleteAssignment: DeleteProgramAssignment,
        reconcile: ReconcileProgramAssignments,
        projectSchedule: ProjectSchedule,
        materializeProjection: MaterializeProjectedWorkout,
        exerciseCatalog: any PlanExerciseCatalog,
        today: @Sendable () -> DayDate = { DayDate(Date()) }
    ) {
        self.listPlanWorkouts = listPlanWorkouts
        self.createPlanWorkout = createPlanWorkout
        self.updatePlanWorkout = updatePlanWorkout
        self.deletePlanWorkout = deletePlanWorkout
        self.listTemplates = listTemplates
        self.instantiateTemplate = instantiateTemplate
        self.listPrograms = listPrograms
        self.listAssignments = listAssignments
        self.applyProgramUseCase = applyProgram
        self.deleteAssignmentUseCase = deleteAssignment
        self.reconcile = reconcile
        self.projectSchedule = projectSchedule
        self.materializeProjection = materializeProjection
        self.exerciseCatalog = exerciseCatalog
        let todayValue = today()
        self.today = todayValue
        self.selectedDate = todayValue
    }

    /// 某天的真實排課（依 orderIndex）。
    public func workouts(on date: DayDate) -> [PlanWorkout] {
        planWorkouts.filter { $0.date == date }.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// 某天的投影建議（未落地）。
    public func projections(on date: DayDate) -> [ProjectedWorkout] {
        projectionsByDate[date] ?? []
    }

    /// 有標記的日子（月曆畫點用）：真實排課 ∪ 投影。
    public var markedDates: Set<DayDate> {
        Set(planWorkouts.map(\.date)).union(projectionsByDate.keys)
    }

    /// 某天的月曆標記：真實排課優先（全完成＝done，否則 scheduled）；只有投影＝projected。
    public func mark(on date: DayDate) -> DayMark? {
        let items = planWorkouts.filter { $0.date == date }
        if !items.isEmpty {
            return items.allSatisfy { $0.status == .done } ? .done : .scheduled
        }
        return (projectionsByDate[date]?.isEmpty == false) ? .projected : nil
    }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    /// 某套用對應的課表名稱（管理清單顯示用）。
    public func programName(for assignment: ProgramAssignment) -> String {
        programs.first { $0.id == assignment.programId }?.name ?? ""
    }

    public func load() async {
        do {
            // 先補登：把過去漏做的長期課表投影落地成「未開始」真實紀錄。
            _ = try await reconcile(today: today)
            planWorkouts = try await listPlanWorkouts()
            templates = try await listTemplates()
            programs = try await listPrograms()
            assignments = try await listAssignments()
            catalog = try await exerciseCatalog.exercises()
            // 投影今天以後一段窗口（涵蓋往後翻幾個月）。
            let projected = try await projectSchedule(
                from: today, to: today.adding(days: 186), today: today
            )
            projectionsByDate = Dictionary(grouping: projected, by: \.date)
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

    /// 把某則投影落地成當天的真實排課（未開始）。
    public func materialize(_ projected: ProjectedWorkout) async {
        await run { _ = try await self.materializeProjection(projected) }
    }

    /// 套用一份長期課表（綁起始日 + 模式），並立即補登過去範圍。
    public func applyProgram(programId: UUID, startDate: DayDate, mode: ProgramRunMode) async {
        await run {
            try await self.applyProgramUseCase(programId: programId, startDate: startDate, mode: mode)
            _ = try await self.reconcile(today: self.today)
        }
    }

    /// 停用一份套用（刪 assignment；過去真實紀錄不動）。
    public func stopAssignment(id: UUID) async {
        await run { try await self.deleteAssignmentUseCase(id: id) }
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
