import Foundation
import HistoryDomain
import Observation

public enum HistoryMode: Hashable, Sendable {
    case byDate
    case byExercise
}

@MainActor
@Observable
public final class HistoryViewModel {
    public var mode: HistoryMode = .byDate

    // 按日期
    public private(set) var workouts: [HistoryWorkoutSummary] = []
    /// 搜尋文字（比對排課名稱；空字串＝不篩選）。
    public var searchText: String = ""

    // 按動作：只是「有紀錄過的動作」清單，點進去才查該動作的歷次場次（見 ExerciseHistoryView）。
    public private(set) var exerciseOptions: [HistoryExerciseOption] = []

    /// 本地化錯誤字串（延後解析，由 View 依 Environment locale 顯示）。
    public private(set) var errorMessage: LocalizedStringResource?

    private let reading: any WorkoutHistoryReading
    private let editing: any WorkoutHistoryEditing

    public init(reading: any WorkoutHistoryReading, editing: any WorkoutHistoryEditing) {
        self.reading = reading
        self.editing = editing
    }

    /// 建立單場詳情頁的 view model。編輯／刪除成功後回呼 `load()`，讓兩種歷史查詢一致更新。
    public func makeDetailViewModel(for id: UUID) -> WorkoutDetailViewModel {
        WorkoutDetailViewModel(
            workoutId: id,
            loadDetail: { [reading] in try? await reading.workoutDetail(id: id) },
            editing: editing,
            onChange: { [weak self] in await self?.load() }
        )
    }

    /// 依搜尋文字篩選（比對排課名稱；沒有名稱的自由訓練用本地化字串比對，由 View 傳入）。
    public func filteredWorkouts(freeTrainingLabel: String) -> [HistoryWorkoutSummary] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return workouts }
        return workouts.filter { ($0.name ?? freeTrainingLabel).localizedCaseInsensitiveContains(searchText) }
    }

    public func load() async {
        do {
            workouts = try await reading.workouts()
            exerciseOptions = try await reading.exercisesWithHistory()
            errorMessage = nil
        } catch {
            errorMessage = .history("history.error.loadHistory \(error.localizedDescription)")
        }
    }

    public func workoutDetail(id: UUID) async -> HistoryWorkoutDetail? {
        do {
            return try await reading.workoutDetail(id: id)
        } catch {
            errorMessage = .history("history.error.loadWorkout \(error.localizedDescription)")
            return nil
        }
    }

    /// 某動作的歷次場次（單一動作歷史頁 `ExerciseHistoryView` 自己的 `.task` 呼叫）。
    public func sessions(for exerciseId: UUID) async -> [HistoryExerciseSession] {
        do {
            return try await reading.sessions(exerciseId: exerciseId)
        } catch {
            errorMessage = .history("history.error.loadExerciseHistory \(error.localizedDescription)")
            return []
        }
    }

    public func dismissError() { errorMessage = nil }
}
