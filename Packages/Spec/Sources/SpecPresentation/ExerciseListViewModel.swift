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
    /// 「常用」分組的次數來源；nil＝不提供（未 wire 的測試與預覽），此時常用分組為空。
    private let usageCounting: (any ExerciseUsageCounting)?

    /// exerciseId → 練過的場次數。`load()` 時一併抓，沒練過的動作不會出現在字典裡。
    public private(set) var usageCounts: [UUID: Int] = [:]

    public init(
        listExercises: ListExercises,
        createExercise: CreateExercise,
        updateExercise: UpdateExercise,
        deleteExercise: DeleteExercise,
        usageListing: (any ExerciseUsageListing)? = nil,
        usageCounting: (any ExerciseUsageCounting)? = nil
    ) {
        self.listExercises = listExercises
        self.createExercise = createExercise
        self.updateExercise = updateExercise
        self.deleteExercise = deleteExercise
        self.usageListing = usageListing
        self.usageCounting = usageCounting
    }

    /// 依練過的場次數由多到少排序；**沒練過的不列入**。
    ///
    /// 一場都沒練過的新使用者會拿到空清單——那是誠實的。舊的佔位邏輯是「取清單前 8 筆」，
    /// 內建動作庫上線後清單常駐 80 筆，等於固定顯示 8 個使用者從沒碰過的動作。
    /// 同次數時用名稱排序，讓輸出穩定（不然每次 Dictionary 走訪順序都可能不同）。
    public var frequentExercises: [Exercise] {
        visibleExercises
            .compactMap { exercise in
                usageCounts[exercise.id].map { (exercise: exercise, count: $0) }
            }
            .sorted {
                $0.count != $1.count
                    ? $0.count > $1.count
                    : $0.exercise.name.localizedStandardCompare($1.exercise.name) == .orderedAscending
            }
            .map(\.exercise)
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
            // 次數抓不到不該讓整個動作庫顯示錯誤——最差的情況是「常用」空著。
            if let usageCounting {
                usageCounts = (try? await usageCounting.usageCounts()) ?? [:]
            }
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
        // UI 不會給內建動作編輯／刪除的入口，所以走到這裡代表有別的路徑漏擋——
        // 給明確訊息比落到 generic 好判讀。
        case ExerciseRepositoryError.readOnly:
            .spec("spec.error.readOnly")
        default:
            .spec("spec.error.generic \(error.localizedDescription)")
        }
    }
}
