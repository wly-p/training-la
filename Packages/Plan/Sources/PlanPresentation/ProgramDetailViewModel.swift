import Foundation
import Observation
import PlanDomain
import SharedKernel

/// 長期詳情頁（設計稿 8a 長期變體）的 VM：進度（day / 週期天數 / 今天）、每天安排清單、
/// 管理動作（重設進度＝回 D1／停用＝刪 assignment／刪除計畫）。編輯走 ProgramEditorViewModel。
@MainActor
@Observable
public final class ProgramDetailViewModel {
    public let programId: UUID
    public private(set) var program: Program?
    public private(set) var progress: ProgramProgress?
    public private(set) var catalog: [PlanCatalogExercise] = []
    public private(set) var errorMessage: LocalizedStringResource?
    public private(set) var didDelete = false

    private let getProgram: GetProgram
    private let getProgress: GetProgramProgress
    private let resetProgress: ResetProgramProgress
    private let deleteAssignment: DeleteProgramAssignment
    private let deleteProgram: DeleteProgram
    private let exerciseCatalog: any PlanExerciseCatalog
    private let today: @Sendable () -> DayDate

    public init(
        programId: UUID,
        getProgram: GetProgram,
        getProgress: GetProgramProgress,
        resetProgress: ResetProgramProgress,
        deleteAssignment: DeleteProgramAssignment,
        deleteProgram: DeleteProgram,
        exerciseCatalog: any PlanExerciseCatalog,
        today: @escaping @Sendable () -> DayDate
    ) {
        self.programId = programId
        self.getProgram = getProgram
        self.getProgress = getProgress
        self.resetProgress = resetProgress
        self.deleteAssignment = deleteAssignment
        self.deleteProgram = deleteProgram
        self.exerciseCatalog = exerciseCatalog
        self.today = today
    }

    public var isActive: Bool { progress != nil }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    public func load() async {
        do {
            program = try await getProgram(id: programId)
            progress = try await getProgress(programId: programId, today: today())
            catalog = try await exerciseCatalog.exercises()
            errorMessage = nil
        } catch {
            errorMessage = .plan("plan.error.loadFailed \(error.localizedDescription)")
        }
    }

    public func resetProgressToStart() async {
        await run { try await self.resetProgress(programId: self.programId, today: self.today()) }
    }

    public func deactivate() async {
        guard let assignmentId = progress?.assignmentId else { return }
        await run { try await self.deleteAssignment(id: assignmentId) }
    }

    public func delete() async {
        do {
            try await deleteProgram(id: programId)
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
