import Foundation
import Observation
import PlanDomain
import SharedKernel

/// 循環課表清單：可多組並行，逐組啟用／停用、重新命名、刪除。內容編輯與建立都走同一個
/// `RotationEditorView`（設計稿 12a：新增／編輯同一頁，不做兩套）。
@MainActor
@Observable
public final class RotationListViewModel {
    public private(set) var rotations: [Rotation] = []
    /// 可加入循環的課表範本（12a「加入範本」的資料源）。
    public private(set) var templates: [WorkoutTemplate] = []
    public private(set) var catalog: [PlanCatalogExercise] = []
    public private(set) var errorMessage: LocalizedStringResource?

    private let listRotations: ListRotations
    private let createRotation: CreateRotation
    private let renameRotation: RenameRotation
    private let saveRotationWorkouts: SaveRotationWorkouts
    private let setRotationActive: SetRotationActive
    private let setRotationIntensityFactor: SetRotationIntensityFactor
    private let deleteRotation: DeleteRotation
    private let listTemplates: ListTemplates
    private let exerciseCatalog: any PlanExerciseCatalog

    public init(
        listRotations: ListRotations,
        createRotation: CreateRotation,
        renameRotation: RenameRotation,
        saveRotationWorkouts: SaveRotationWorkouts,
        setRotationActive: SetRotationActive,
        setRotationIntensityFactor: SetRotationIntensityFactor,
        deleteRotation: DeleteRotation,
        listTemplates: ListTemplates,
        exerciseCatalog: any PlanExerciseCatalog
    ) {
        self.listRotations = listRotations
        self.createRotation = createRotation
        self.renameRotation = renameRotation
        self.saveRotationWorkouts = saveRotationWorkouts
        self.setRotationActive = setRotationActive
        self.setRotationIntensityFactor = setRotationIntensityFactor
        self.deleteRotation = deleteRotation
        self.listTemplates = listTemplates
        self.exerciseCatalog = exerciseCatalog
    }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    public func load() async {
        do {
            rotations = try await listRotations()
            templates = try await listTemplates()
            catalog = try await exerciseCatalog.exercises()
            errorMessage = nil
        } catch {
            errorMessage = .plan("plan.error.loadFailed \(error.localizedDescription)")
        }
    }

    public func create(
        name: String, workouts: [WorkoutSpec], isActive: Bool, cursor: Int, intensityFactor: Double = 1.0
    ) async {
        await run {
            try await self.createRotation(
                name: name, workouts: workouts, isActive: isActive, cursor: cursor, intensityFactor: intensityFactor
            )
        }
    }

    public func update(id: UUID, name: String, workouts: [WorkoutSpec], intensityFactor: Double) async {
        await run {
            try await self.renameRotation(id: id, name: name)
            try await self.saveRotationWorkouts(id: id, workouts: workouts)
            try await self.setRotationIntensityFactor(id: id, intensityFactor: intensityFactor)
        }
    }

    public func rename(id: UUID, name: String) async {
        await run { try await self.renameRotation(id: id, name: name) }
    }

    public func setActive(id: UUID, _ isActive: Bool) async {
        await run { try await self.setRotationActive(id: id, isActive: isActive) }
    }

    public func delete(id: UUID) async {
        await run { try await self.deleteRotation(id: id) }
    }

    public func dismissError() { errorMessage = nil }

    private func run(_ operation: @escaping () async throws -> Void) async {
        do {
            try await operation()
            await load()
        } catch PlanWorkoutValidationError.emptyName {
            errorMessage = .plan("rotation.error.needName")
        } catch PlanWorkoutValidationError.empty {
            errorMessage = .plan("plan.error.needExercise")
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
        }
    }
}
