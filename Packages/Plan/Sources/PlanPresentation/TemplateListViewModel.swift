import Foundation
import Observation
import PlanDomain
import SharedKernel

@MainActor
@Observable
public final class TemplateListViewModel {
    public private(set) var templates: [WorkoutTemplate] = []
    public private(set) var catalog: [PlanCatalogExercise] = []
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
        exerciseCatalog: any PlanExerciseCatalog
    ) {
        self.listTemplates = listTemplates
        self.createTemplate = createTemplate
        self.updateTemplate = updateTemplate
        self.deleteTemplate = deleteTemplate
        self.duplicateTemplate = duplicateTemplate
        self.exerciseCatalog = exerciseCatalog
    }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
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
    public func duplicate(id: UUID) async -> WorkoutTemplate? {
        do {
            let copy = try await duplicateTemplate(id: id)
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
