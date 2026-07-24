import Foundation
import Observation
import PlanDomain
import SharedKernel

/// 長期課表清單：可多份，逐份建立/刪除；內容編輯走 ProgramEditorViewModel。
@MainActor
@Observable
public final class ProgramListViewModel {
    public private(set) var programs: [Program] = []
    public private(set) var errorMessage: LocalizedStringResource?

    private let listPrograms: ListPrograms
    private let createProgram: CreateProgram
    private let deleteProgram: DeleteProgram

    public init(
        listPrograms: ListPrograms,
        createProgram: CreateProgram,
        deleteProgram: DeleteProgram
    ) {
        self.listPrograms = listPrograms
        self.createProgram = createProgram
        self.deleteProgram = deleteProgram
    }

    public func load() async {
        do {
            programs = try await listPrograms()
            errorMessage = nil
        } catch {
            errorMessage = .plan("plan.error.loadFailed \(error.localizedDescription)")
        }
    }

    public func create(name: String, cycleLength: Int) async {
        await run { try await self.createProgram(name: name, cycleLength: cycleLength) }
    }

    public func delete(id: UUID) async {
        await run { try await self.deleteProgram(id: id) }
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
