import Foundation
import Observation
import SharedKernel
import SpecDomain

@MainActor
@Observable
public final class ExerciseListViewModel {
    public private(set) var exercises: [Exercise] = []
    /// 本地化錯誤字串（延後解析，由 View 依 Environment locale 顯示）。
    public private(set) var errorMessage: LocalizedStringResource?
    public var filter: MuscleGroup?
    public var searchText: String = ""

    private let listExercises: ListExercises
    private let createExercise: CreateExercise
    private let updateExercise: UpdateExercise
    private let deleteExercise: DeleteExercise
    /// 「被使用於」名稱反查（編輯頁 9a 護欄）；nil＝不顯示（例如未 wire 的測試）。
    private let usageListing: (any ExerciseUsageListing)?

    public init(
        listExercises: ListExercises,
        createExercise: CreateExercise,
        updateExercise: UpdateExercise,
        deleteExercise: DeleteExercise,
        usageListing: (any ExerciseUsageListing)? = nil
    ) {
        self.listExercises = listExercises
        self.createExercise = createExercise
        self.updateExercise = updateExercise
        self.deleteExercise = deleteExercise
        self.usageListing = usageListing
    }

    /// 查某動作被哪些範本/循環/長期使用（編輯頁載入時呼叫）。未 wire 時回空。
    public func usages(of exerciseId: UUID) async -> [ExerciseUsageRef] {
        guard let usageListing else { return [] }
        return (try? await usageListing.usages(exerciseId: exerciseId)) ?? []
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

    public func add(name: String, muscleGroup: MuscleGroup, equipment: Equipment, description: String?) async {
        do {
            try await createExercise(name: name, muscleGroup: muscleGroup, equipment: equipment, description: description)
            await load()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    public func edit(id: UUID, name: String, muscleGroup: MuscleGroup, equipment: Equipment, description: String?) async {
        do {
            try await updateExercise(id: id, name: name, muscleGroup: muscleGroup, equipment: equipment, description: description)
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

    private static func message(for error: Error) -> LocalizedStringResource {
        switch error {
        case ExerciseValidationError.emptyName:
            .spec("spec.error.nameBlank")
        case ExerciseValidationError.nameTooLong(let max):
            .spec("spec.error.nameTooLong \(max)")
        case ExerciseRepositoryError.notFound:
            .spec("spec.error.notFound")
        case ExerciseRepositoryError.inUse:
            .spec("spec.error.inUse")
        default:
            .spec("spec.error.generic \(error.localizedDescription)")
        }
    }
}
