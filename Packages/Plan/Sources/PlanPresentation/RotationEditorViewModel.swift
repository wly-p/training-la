import Foundation
import Observation
import PlanDomain
import SharedKernel

/// 單一循環課表的內容編輯器：載入某組循環的名稱與 workouts，增刪改順序。
@MainActor
@Observable
public final class RotationEditorViewModel {
    public let rotationId: UUID
    public private(set) var name: String = ""
    public private(set) var workouts: [WorkoutSpec] = []
    public private(set) var catalog: [PlanCatalogExercise] = []
    public private(set) var errorMessage: LocalizedStringResource?

    private let getRotation: GetRotation
    private let saveRotationWorkouts: SaveRotationWorkouts
    private let exerciseCatalog: any PlanExerciseCatalog

    public init(
        rotationId: UUID,
        getRotation: GetRotation,
        saveRotationWorkouts: SaveRotationWorkouts,
        exerciseCatalog: any PlanExerciseCatalog
    ) {
        self.rotationId = rotationId
        self.getRotation = getRotation
        self.saveRotationWorkouts = saveRotationWorkouts
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
            errorMessage = nil
        } catch {
            errorMessage = .plan("plan.error.loadFailed \(error.localizedDescription)")
        }
    }

    public func add(name: String, drafts: [ExerciseTargetDraft]) async {
        var next = workouts
        next.append(WorkoutSpec(name: name, sets: PlanSet.make(from: drafts)))
        await persist(next)
    }

    public func update(id: UUID, name: String, drafts: [ExerciseTargetDraft]) async {
        let next = workouts.map { spec in
            spec.id == id ? WorkoutSpec(id: id, name: name, sets: PlanSet.make(from: drafts)) : spec
        }
        await persist(next)
    }

    public func delete(at offsets: IndexSet) async {
        var next = workouts
        next.remove(atOffsets: offsets)
        await persist(next)
    }

    public func move(from source: IndexSet, to destination: Int) async {
        var next = workouts
        next.move(fromOffsets: source, toOffset: destination)
        await persist(next)
    }

    public func dismissError() { errorMessage = nil }

    private func persist(_ next: [WorkoutSpec]) async {
        do {
            try await saveRotationWorkouts(id: rotationId, workouts: next)
            workouts = try await getRotation(id: rotationId)?.workouts ?? next
            errorMessage = nil
        } catch {
            errorMessage = .plan("plan.error.actionFailed \(error.localizedDescription)")
        }
    }
}
