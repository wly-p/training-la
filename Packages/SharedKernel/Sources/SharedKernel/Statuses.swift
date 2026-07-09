/// 每組實際執行狀態（rawValue 對齊 API 契約）。
public enum WorkoutSetStatus: String, CaseIterable, Codable, Sendable {
    case done
    case skipped
    case interrupted
}

/// 排課狀態（rawValue 對齊 API 契約）。
public enum PlanWorkoutStatus: String, CaseIterable, Codable, Sendable {
    case notStarted = "not_started"
    case done
    case skipped
}
