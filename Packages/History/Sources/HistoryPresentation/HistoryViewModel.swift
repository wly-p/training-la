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

    // 按動作
    public private(set) var exerciseOptions: [HistoryExerciseOption] = []
    public var selectedExerciseId: UUID? {
        didSet {
            if selectedExerciseId != oldValue {
                Task { await loadSessions() }
            }
        }
    }
    public private(set) var sessions: [HistoryExerciseSession] = []

    public private(set) var errorMessage: String?

    private let reading: any WorkoutHistoryReading

    public init(reading: any WorkoutHistoryReading) {
        self.reading = reading
    }

    public var selectedExerciseSessionCount: Int { sessions.count }

    public func load() async {
        do {
            workouts = try await reading.workouts()
            exerciseOptions = try await reading.exercisesWithHistory()
            // 預設選第一個有紀錄的動作
            if selectedExerciseId == nil {
                selectedExerciseId = exerciseOptions.first?.id
            } else {
                await loadSessions()
            }
            errorMessage = nil
        } catch {
            errorMessage = "讀取歷史失敗：\(error.localizedDescription)"
        }
    }

    public func workoutDetail(id: UUID) async -> HistoryWorkoutDetail? {
        do {
            return try await reading.workoutDetail(id: id)
        } catch {
            errorMessage = "讀取場次失敗：\(error.localizedDescription)"
            return nil
        }
    }

    public func dismissError() { errorMessage = nil }

    private func loadSessions() async {
        guard let id = selectedExerciseId else {
            sessions = []
            return
        }
        do {
            sessions = try await reading.sessions(exerciseId: id)
        } catch {
            errorMessage = "讀取動作歷史失敗：\(error.localizedDescription)"
        }
    }
}
