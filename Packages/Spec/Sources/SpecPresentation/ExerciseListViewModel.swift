import Foundation
import Observation
import SharedKernel
import SpecDomain

@MainActor
@Observable
public final class ExerciseListViewModel {
    public private(set) var exercises: [Exercise] = []
    public private(set) var errorMessage: String?
    public var filter: MuscleGroup?
    public var searchText: String = ""

    private let listExercises: ListExercises
    private let createExercise: CreateExercise
    private let updateExercise: UpdateExercise
    private let deleteExercise: DeleteExercise

    public init(
        listExercises: ListExercises,
        createExercise: CreateExercise,
        updateExercise: UpdateExercise,
        deleteExercise: DeleteExercise
    ) {
        self.listExercises = listExercises
        self.createExercise = createExercise
        self.updateExercise = updateExercise
        self.deleteExercise = deleteExercise
    }

    public var visibleExercises: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedStandardContains(searchText) }
    }

    public func load() async {
        do {
            exercises = try await listExercises(muscleGroup: filter)
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    public func setFilter(_ muscleGroup: MuscleGroup?) async {
        filter = muscleGroup
        await load()
    }

    public func add(name: String, muscleGroup: MuscleGroup, description: String?) async {
        do {
            try await createExercise(name: name, muscleGroup: muscleGroup, description: description)
            await load()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    public func edit(id: UUID, name: String, muscleGroup: MuscleGroup, description: String?) async {
        do {
            try await updateExercise(id: id, name: name, muscleGroup: muscleGroup, description: description)
            await load()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    public func remove(id: UUID) async {
        do {
            try await deleteExercise(id: id)
            await load()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    public func dismissError() {
        errorMessage = nil
    }

    private static func message(for error: Error) -> String {
        switch error {
        case ExerciseValidationError.emptyName:
            "動作名稱不能是空白"
        case ExerciseValidationError.nameTooLong(let max):
            "動作名稱最長 \(max) 字"
        case ExerciseRepositoryError.notFound:
            "找不到這個動作，可能已被刪除"
        case ExerciseRepositoryError.inUse:
            "此動作已被課表或訓練紀錄使用，無法刪除"
        default:
            "發生錯誤：\(error.localizedDescription)"
        }
    }
}
