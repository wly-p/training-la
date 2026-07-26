import Foundation
import Observation
import PlanDomain
import SharedKernel

/// 長期課表清單：可多份，逐份建立/刪除；內容編輯與建立都走同一個 `ProgramEditorView`
/// （設計稿 12b：新增／編輯同一頁，不做兩套）。
/// 進行中／未啟用由**真實 assignment** 判定（設計稿 5d／8a）；進行中卡的進度由 GetProgramProgress 算。
@MainActor
@Observable
public final class ProgramListViewModel {
    public private(set) var programs: [Program] = []
    /// programId → 此刻進度（有 assignment 才有）。key 存在即「進行中」。
    public private(set) var progressByProgram: [UUID: ProgramProgress] = [:]
    /// 可指派到週期格的課表範本（12b 選擇器的資料源）。
    public private(set) var templates: [WorkoutTemplate] = []
    public private(set) var catalog: [PlanCatalogExercise] = []
    public private(set) var errorMessage: LocalizedStringResource?

    private let listPrograms: ListPrograms
    private let listAssignments: ListProgramAssignments
    private let getProgress: GetProgramProgress
    private let createProgram: CreateProgram
    private let updateProgram: UpdateProgram
    private let deleteProgram: DeleteProgram
    private let applyProgram: ApplyProgram
    private let listTemplates: ListTemplates
    private let exerciseCatalog: any PlanExerciseCatalog
    private let today: @Sendable () -> DayDate

    public init(
        listPrograms: ListPrograms,
        listAssignments: ListProgramAssignments,
        getProgress: GetProgramProgress,
        createProgram: CreateProgram,
        updateProgram: UpdateProgram,
        deleteProgram: DeleteProgram,
        applyProgram: ApplyProgram,
        listTemplates: ListTemplates,
        exerciseCatalog: any PlanExerciseCatalog,
        today: @escaping @Sendable () -> DayDate
    ) {
        self.listPrograms = listPrograms
        self.listAssignments = listAssignments
        self.getProgress = getProgress
        self.createProgram = createProgram
        self.updateProgram = updateProgram
        self.deleteProgram = deleteProgram
        self.applyProgram = applyProgram
        self.listTemplates = listTemplates
        self.exerciseCatalog = exerciseCatalog
        self.today = today
    }

    /// 進行中（有 assignment）／未啟用兩分區，各自維持 orderIndex 排序。
    public var activePrograms: [Program] { programs.filter { progressByProgram[$0.id] != nil } }
    public var inactivePrograms: [Program] { programs.filter { progressByProgram[$0.id] == nil } }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    public func load() async {
        do {
            programs = try await listPrograms()
            let assignments = try await listAssignments()
            let activeIds = Set(assignments.map(\.programId))
            var map: [UUID: ProgramProgress] = [:]
            for program in programs where activeIds.contains(program.id) {
                if let p = try await getProgress(programId: program.id, today: today()) {
                    map[program.id] = p
                }
            }
            progressByProgram = map
            templates = try await listTemplates()
            catalog = try await exerciseCatalog.exercises()
            errorMessage = nil
        } catch {
            errorMessage = .plan("plan.error.loadFailed \(error.localizedDescription)")
        }
    }

    public func create(name: String, cycleLength: Int, days: [Int: WorkoutSpec]) async {
        await run { try await self.createProgram(name: name, cycleLength: cycleLength, days: days) }
    }

    public func update(id: UUID, name: String, cycleLength: Int, days: [Int: WorkoutSpec]) async {
        await run { try await self.updateProgram(id: id, name: name, cycleLength: cycleLength, days: days) }
    }

    public func delete(id: UUID) async {
        await run { try await self.deleteProgram(id: id) }
    }

    /// 啟用（未啟用列「啟用」）：以今天為起始、重複模式套用一份 assignment（＝變進行中）。
    /// 指定起始日／模式的完整套用流程在課表 tab；這裡給清單一個直接啟用的合理預設。
    public func activate(id: UUID) async {
        await run { _ = try await self.applyProgram(programId: id, startDate: self.today(), mode: .repeating) }
    }

    public func dismissError() { errorMessage = nil }

    private func run(_ operation: @escaping () async throws -> Void) async {
        do {
            try await operation()
            await load()
        } catch PlanWorkoutValidationError.emptyName {
            errorMessage = .plan("program.error.needName")
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
        }
    }
}
