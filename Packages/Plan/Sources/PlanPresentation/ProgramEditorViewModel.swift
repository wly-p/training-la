import Foundation
import Observation
import PlanDomain
import SharedKernel

/// 單一長期課表的內容編輯器（設計稿 9c）：載入現況給 View 建本地草稿，
/// 草稿只在使用者按「儲存」時一次性寫回（`save`）；「取消」不留痕跡。
@MainActor
@Observable
public final class ProgramEditorViewModel {
    public let programId: UUID
    public private(set) var name: String = ""
    public private(set) var cycleLength: Int = 7
    public private(set) var days: [Int: WorkoutSpec] = [:]
    public private(set) var catalog: [PlanCatalogExercise] = []
    /// 可帶入的課表範本（「從範本帶入」用）。
    public private(set) var templates: [WorkoutTemplate] = []
    public private(set) var errorMessage: LocalizedStringResource?

    private let getProgram: GetProgram
    private let updateProgram: UpdateProgram
    private let deleteProgram: DeleteProgram
    private let listTemplates: ListTemplates
    private let exerciseCatalog: any PlanExerciseCatalog

    public init(
        programId: UUID,
        getProgram: GetProgram,
        updateProgram: UpdateProgram,
        deleteProgram: DeleteProgram,
        listTemplates: ListTemplates,
        exerciseCatalog: any PlanExerciseCatalog
    ) {
        self.programId = programId
        self.getProgram = getProgram
        self.updateProgram = updateProgram
        self.deleteProgram = deleteProgram
        self.listTemplates = listTemplates
        self.exerciseCatalog = exerciseCatalog
    }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    public func load() async {
        do {
            let program = try await getProgram(id: programId)
            name = program?.name ?? ""
            cycleLength = program?.cycleLength ?? 7
            days = program?.days ?? [:]
            catalog = try await exerciseCatalog.exercises()
            templates = try await listTemplates()
            errorMessage = nil
        } catch {
            errorMessage = .plan("plan.error.loadFailed \(error.localizedDescription)")
        }
    }

    /// 把整份草稿（名稱／週期／每天安排）一次寫回；成功才讓 View 退出編輯頁。
    @discardableResult
    public func save(name: String, cycleLength: Int, days: [Int: WorkoutSpec]) async -> Bool {
        do {
            try await updateProgram(id: programId, name: name, cycleLength: cycleLength, days: days)
            errorMessage = nil
            return true
        } catch PlanWorkoutValidationError.emptyName {
            errorMessage = .plan("program.error.needName")
            return false
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    public func delete() async -> Bool {
        do {
            try await deleteProgram(id: programId)
            return true
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
            return false
        }
    }

    public func dismissError() { errorMessage = nil }
}
