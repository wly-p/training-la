import Foundation
import Observation
import PlanDomain
import SharedKernel

/// 單一循環課表的內容編輯器（設計稿骨架，同 9c 一套）：載入現況給 View 建本地草稿，
/// 草稿只在使用者按「儲存」時一次性寫回（`save`）；「取消」不留痕跡。
@MainActor
@Observable
public final class RotationEditorViewModel {
    public let rotationId: UUID
    public private(set) var name: String = ""
    public private(set) var workouts: [WorkoutSpec] = []
    public private(set) var catalog: [PlanCatalogExercise] = []
    /// 可帶入的課表範本（「從範本帶入」用）。
    public private(set) var templates: [WorkoutTemplate] = []
    public private(set) var errorMessage: LocalizedStringResource?

    private let getRotation: GetRotation
    private let renameRotation: RenameRotation
    private let saveRotationWorkouts: SaveRotationWorkouts
    private let deleteRotation: DeleteRotation
    private let listTemplates: ListTemplates
    private let exerciseCatalog: any PlanExerciseCatalog

    public init(
        rotationId: UUID,
        getRotation: GetRotation,
        renameRotation: RenameRotation,
        saveRotationWorkouts: SaveRotationWorkouts,
        deleteRotation: DeleteRotation,
        listTemplates: ListTemplates,
        exerciseCatalog: any PlanExerciseCatalog
    ) {
        self.rotationId = rotationId
        self.getRotation = getRotation
        self.renameRotation = renameRotation
        self.saveRotationWorkouts = saveRotationWorkouts
        self.deleteRotation = deleteRotation
        self.listTemplates = listTemplates
        self.exerciseCatalog = exerciseCatalog
    }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    public func load() async {
        do {
            let rotation = try await getRotation(id: rotationId)
            name = rotation?.name ?? ""
            workouts = rotation?.workouts ?? []
            catalog = try await exerciseCatalog.exercises()
            templates = try await listTemplates()
            errorMessage = nil
        } catch {
            errorMessage = .plan("plan.error.loadFailed \(error.localizedDescription)")
        }
    }

    /// 把整份草稿（名稱／範本順序）一次寫回；成功才讓 View 退出編輯頁。
    @discardableResult
    public func save(name: String, workouts: [WorkoutSpec]) async -> Bool {
        do {
            try await renameRotation(id: rotationId, name: name)
            try await saveRotationWorkouts(id: rotationId, workouts: workouts)
            errorMessage = nil
            return true
        } catch PlanWorkoutValidationError.emptyName {
            errorMessage = .plan("rotation.error.needName")
            return false
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    public func delete() async -> Bool {
        do {
            try await deleteRotation(id: rotationId)
            return true
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
            return false
        }
    }

    public func dismissError() { errorMessage = nil }
}
