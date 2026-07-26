import Foundation
import Observation
import PlanDomain
import SharedKernel

/// 循環詳情頁（設計稿 8a）的 VM：狀態卡（輪數/已完成次數/範本 capsule）、組成清單、
/// 管理動作（跳到下一個範本／重設輪次／停用／刪除）。編輯內容走 RotationEditorViewModel。
@MainActor
@Observable
public final class RotationDetailViewModel {
    public let rotationId: UUID
    public private(set) var rotation: Rotation?
    public private(set) var catalog: [PlanCatalogExercise] = []
    public private(set) var errorMessage: LocalizedStringResource?
    /// 刪除後由 View pop 回清單。
    public private(set) var didDelete = false

    private let getRotation: GetRotation
    private let advanceRotation: AdvanceRotation
    private let resetRotation: ResetRotation
    private let setRotationActive: SetRotationActive
    private let deleteRotation: DeleteRotation
    private let exerciseCatalog: any PlanExerciseCatalog

    public init(
        rotationId: UUID,
        getRotation: GetRotation,
        advanceRotation: AdvanceRotation,
        resetRotation: ResetRotation,
        setRotationActive: SetRotationActive,
        deleteRotation: DeleteRotation,
        exerciseCatalog: any PlanExerciseCatalog
    ) {
        self.rotationId = rotationId
        self.getRotation = getRotation
        self.advanceRotation = advanceRotation
        self.resetRotation = resetRotation
        self.setRotationActive = setRotationActive
        self.deleteRotation = deleteRotation
        self.exerciseCatalog = exerciseCatalog
    }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    /// 目前輪到第幾張（0-based cursor）—— 組成清單標出當前那張。
    public var currentIndex: Int { rotation?.cursor ?? 0 }

    public func load() async {
        do {
            rotation = try await getRotation(id: rotationId)
            catalog = try await exerciseCatalog.exercises()
            errorMessage = nil
        } catch {
            errorMessage = .plan("plan.error.loadFailed \(error.localizedDescription)")
        }
    }

    public func advance() async { await run { try await self.advanceRotation(id: self.rotationId) } }
    public func reset() async { await run { try await self.resetRotation(id: self.rotationId) } }
    public func deactivate() async {
        await run { try await self.setRotationActive(id: self.rotationId, isActive: false) }
    }

    public func delete() async {
        do {
            try await deleteRotation(id: rotationId)
            didDelete = true
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
        }
    }

    public func dismissError() { errorMessage = nil }

    private func run(_ operation: @escaping () async throws -> Void) async {
        do {
            try await operation()
            await load()
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
        }
    }
}
