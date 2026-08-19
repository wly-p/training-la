import Foundation
import Observation
import PlanDomain
import SharedKernel

/// 某天的排課狀態（給月曆的格子）。原本住在 `MonthCalendarView`（原生 `UICalendarView`
/// 的包裝，已隨月檢視 sheet 一起刪掉），它其實是 view model 的輸出，搬回這裡。
public enum DayMark: Equatable, Sendable {
    case scheduled   // 有未完成排課（真實紀錄）
    case done        // 當天排課都已完成
    case projected   // 長期課表投影，尚未按「加入這天」落地
}

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
        /// 使用者的重量級距偏好；表單的 ± 快捷與滾輪用。
    /// 即時讀取不快取——這個 view model 活很久，設定改了要馬上反映。
    public var weightStep: Double { preferences.loadWeightStep() }
    private let preferences: any TrainingPreferenceStoring
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
    /// 由外部注入（UI test 用 `--uitest-today` 釘死），月曆的「今天」短槓也吃這一個。
    ///
    /// **存 closure 而不是存算好的值**：這個 view model 活整個 app 生命週期，
    /// 存成 `let today: DayDate` 的話 app 一直開著跨過午夜，月曆的今天標記、
    /// 補登邊界（`scanEnd = today - 1`）、投影起點會全部停在昨天，直到重啟 app。
    private let todayProvider: @Sendable () -> DayDate
    var today: DayDate { todayProvider() }

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
        preferences: any TrainingPreferenceStoring = InMemoryTrainingPreferenceStore(),
        today: @escaping @Sendable () -> DayDate = { DayDate(Date()) }
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
        self.preferences = preferences
        self.todayProvider = today
        // 選取日只是初值，之後由使用者操作決定，不跟著時鐘走。
        self.selectedDate = today()
    }

    /// 某天的真實排課（依 orderIndex）。
    public func workouts(on date: DayDate) -> [PlanWorkout] {
        planWorkouts.filter { $0.date == date }.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// 某天的投影建議（未落地）。
    public func projections(on date: DayDate) -> [ProjectedWorkout] {
        projectionsByDate[date] ?? []
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
        // 查不到＝該動作已被刪；正常流程進不來（刪除前有 ExerciseUsageChecker 擋）。
        // 用中性符號而非任何語言的字，這裡拿不到 locale。
        catalog.first { $0.id == exerciseId }?.name ?? "—"
    }

    /// 某月已完成的排課次數（「月檢視」入口列的摘要用）。
    public func monthCompletedCount(for date: DayDate) -> Int {
        planWorkouts.filter { $0.status == .done && $0.date.year == date.year && $0.date.month == date.month }.count
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
