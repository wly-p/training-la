import Foundation
import SettingsPresentation
import SpecDomain
import TrainingDomain

/// Settings 的「匯出訓練歷史」port ← Training 的 `ExportWorkoutHistory` ＋ Spec 的動作名稱。
/// Settings package 不依賴 Training／Spec，兩邊只在這裡（Composition Root）接線。
struct WorkoutExportAdapter: WorkoutHistoryExporting {
    let exportHistory: ExportWorkoutHistory
    let listExercises: ListExercises

    func exportJSON() async throws -> URL {
        // 兩者互不依賴，平行抓取縮短匯出等待時間。
        async let workoutsResult = workouts()
        async let namesResult = nameLookup()
        return try write(
            WorkoutHistoryExporter.json(from: try await workoutsResult, exerciseNames: try await namesResult),
            filename: "training-history.json"
        )
    }

    func exportCSV() async throws -> URL {
        async let workoutsResult = workouts()
        async let namesResult = nameLookup()
        return try write(
            WorkoutHistoryExporter.csv(from: try await workoutsResult, exerciseNames: try await namesResult),
            filename: "training-history.csv"
        )
    }

    private func workouts() async throws -> [Workout] {
        try await exportHistory()
    }

    private func nameLookup() async throws -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: try await listExercises(muscleGroup: nil).map { ($0.id, $0.name) })
    }

    /// 寫進暫存目錄，交給 `ActivityShareSheet` 分享；每次匯出用固定檔名覆蓋前一份，
    /// 不在裝置上累積歷史匯出檔案。
    private func write(_ data: Data, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}
