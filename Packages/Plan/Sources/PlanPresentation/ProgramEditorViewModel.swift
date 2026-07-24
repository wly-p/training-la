import Foundation
import Observation
import PlanDomain
import SharedKernel

/// 單一長期課表的內容編輯器：改名稱、調週期天數、逐天指定 workout 或留空（休息）。
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
    private let listTemplates: ListTemplates
    private let exerciseCatalog: any PlanExerciseCatalog

    public init(
        programId: UUID,
        getProgram: GetProgram,
        updateProgram: UpdateProgram,
        listTemplates: ListTemplates,
        exerciseCatalog: any PlanExerciseCatalog
    ) {
        self.programId = programId
        self.getProgram = getProgram
        self.updateProgram = updateProgram
        self.listTemplates = listTemplates
        self.exerciseCatalog = exerciseCatalog
    }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    /// 第 index 天排的 workout（nil＝休息）。
    public func workout(day index: Int) -> WorkoutSpec? { days[index] }

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

    public func rename(_ newName: String) async {
        await persist(name: newName, cycleLength: cycleLength, days: days)
    }

    public func setCycleLength(_ length: Int) async {
        let clamped = max(1, min(length, 60))
        await persist(name: name, cycleLength: clamped, days: days)
    }

    /// 指定第 index 天的 workout。
    public func setDay(_ index: Int, name workoutName: String, drafts: [ExerciseTargetDraft]) async {
        var next = days
        next[index] = WorkoutSpec(name: workoutName, sets: PlanSet.make(from: drafts))
        await persist(name: name, cycleLength: cycleLength, days: next)
    }

    /// 把第 index 天清成休息。
    public func clearDay(_ index: Int) async {
        var next = days
        next[index] = nil
        await persist(name: name, cycleLength: cycleLength, days: next)
    }

    public func dismissError() { errorMessage = nil }

    private func persist(name: String, cycleLength: Int, days: [Int: WorkoutSpec]) async {
        do {
            try await updateProgram(id: programId, name: name, cycleLength: cycleLength, days: days)
            let program = try await getProgram(id: programId)
            self.name = program?.name ?? name
            self.cycleLength = program?.cycleLength ?? cycleLength
            self.days = program?.days ?? days
            errorMessage = nil
        } catch PlanWorkoutValidationError.emptyName {
            errorMessage = .plan("program.error.needName")
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
        }
    }
}
