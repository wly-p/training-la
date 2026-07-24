import Foundation
import Observation
import PlanDomain
import SharedKernel

/// 循環課表清單：可多組並行，逐組啟用／停用、重新命名、刪除。內容編輯走 RotationEditorViewModel。
@MainActor
@Observable
public final class RotationListViewModel {
    public private(set) var rotations: [Rotation] = []
    public private(set) var errorMessage: LocalizedStringResource?

    private let listRotations: ListRotations
    private let createRotation: CreateRotation
    private let renameRotation: RenameRotation
    private let setRotationActive: SetRotationActive
    private let deleteRotation: DeleteRotation

    public init(
        listRotations: ListRotations,
        createRotation: CreateRotation,
        renameRotation: RenameRotation,
        setRotationActive: SetRotationActive,
        deleteRotation: DeleteRotation
    ) {
        self.listRotations = listRotations
        self.createRotation = createRotation
        self.renameRotation = renameRotation
        self.setRotationActive = setRotationActive
        self.deleteRotation = deleteRotation
    }

    public func load() async {
        do {
            rotations = try await listRotations()
            errorMessage = nil
        } catch {
            errorMessage = .plan("plan.error.loadFailed \(error.localizedDescription)")
        }
    }

    public func create(name: String) async {
        await run { try await self.createRotation(name: name) }
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
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
        }
    }
}
