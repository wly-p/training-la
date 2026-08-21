import Foundation
import Observation
import PlanDomain
import SharedKernel

@MainActor
@Observable
public final class TemplateListViewModel {
    public private(set) var templates: [WorkoutTemplate] = []
    public private(set) var catalog: [PlanCatalogExercise] = []
        /// 使用者的重量級距偏好；逐組編輯的 ± 快捷與滾輪用。
    /// 即時讀取不快取——這個 view model 活很久，設定改了要馬上反映。
    public var weightStep: Double { preferences.loadWeightStep() }
    private let preferences: any TrainingPreferenceStoring
    /// 本地化錯誤字串（延後解析，由 View 依 Environment locale 顯示）。
    public private(set) var errorMessage: LocalizedStringResource?

    private let listTemplates: ListTemplates
    private let createTemplate: CreateTemplate
    private let updateTemplate: UpdateTemplate
    private let deleteTemplate: DeleteTemplate
    private let duplicateTemplate: DuplicateTemplate
    private let exerciseCatalog: any PlanExerciseCatalog

    public init(
        listTemplates: ListTemplates,
        createTemplate: CreateTemplate,
        updateTemplate: UpdateTemplate,
        deleteTemplate: DeleteTemplate,
        duplicateTemplate: DuplicateTemplate,
        exerciseCatalog: any PlanExerciseCatalog,
        preferences: any TrainingPreferenceStoring = InMemoryTrainingPreferenceStore()
    ) {
        self.listTemplates = listTemplates
        self.createTemplate = createTemplate
        self.updateTemplate = updateTemplate
        self.deleteTemplate = deleteTemplate
        self.duplicateTemplate = duplicateTemplate
        self.preferences = preferences
        self.exerciseCatalog = exerciseCatalog
    }

    public func name(for exerciseId: UUID) -> String {
        // 查不到＝該動作已被刪；正常流程進不來（刪除前有 ExerciseUsageChecker 擋）。
        // 用中性符號而非任何語言的字，這裡拿不到 locale。
        catalog.first { $0.id == exerciseId }?.name ?? "—"
    }

    public func load() async {
        do {
            templates = try await listTemplates()
            catalog = try await exerciseCatalog.exercises()
            errorMessage = nil
        } catch {
            errorMessage = .plan("plan.error.loadFailed \(error.localizedDescription)")
        }
    }

    public func create(name: String, sets: [PlanSet]) async {
        await run { try await self.createTemplate(name: name, sets: sets) }
    }

    public func update(id: UUID, name: String, sets: [PlanSet]) async {
        await run { try await self.updateTemplate(id: id, name: name, sets: sets) }
    }

    public func delete(id: UUID) async {
        await run { try await self.deleteTemplate(id: id) }
    }

    /// 左滑「複製」（14a）：深拷貝已存進 repository，回傳新的一份給呼叫端直接開編輯頁。
    @discardableResult
    /// `nameSuffix` 由 View 傳入（它才拿得到 locale）——複製出來的名稱會被存進 DB，
    /// 必須在寫入當下解析成使用者當時的語言。
    public func duplicate(id: UUID, nameSuffix: String) async -> WorkoutTemplate? {
        do {
            let copy = try await duplicateTemplate(id: id, nameSuffix: nameSuffix)
            await load()
            return copy
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
            return nil
        }
    }

    public func dismissError() { errorMessage = nil }

    private func run(_ operation: @escaping () async throws -> Void) async {
        do {
            try await operation()
            await load()
        } catch PlanWorkoutValidationError.empty {
            errorMessage = .plan("plan.error.needExercise")
        } catch PlanWorkoutValidationError.emptyName {
            errorMessage = .plan("template.error.needName")
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
        }
    }
}
