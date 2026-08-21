import Foundation
import SharedKernel
import SwiftData
import Testing
import TrainingDomain

@testable import TrainingData

/// 讀取路徑的量測。**預設不跑**（會多花數秒、輸出也只是給人看的數字）：
///
/// ```
/// BENCH=1 swift test --filter ReadPathBenchmark
/// ```
///
/// 留著而不是量完就刪：D1（`save` 改 diff 寫入）之後也要用同一把尺量，
/// 而「憑印象說變快了」是效能工作最常見的錯誤。
///
/// 2026-08 在 200 場 × 25 組下的基準：
/// | 呼叫 | 改前 | 改後 |
/// |---|---|---|
/// | `exerciseHistory()` ×5（結束訓練的 PR 偵測） | 1.372s | 0.025s |
/// | `finishedWorkouts()` ×5（進訓練分頁） | 1.433s | 0.436s（改用 limit: 60） |
struct ReadPathBenchmark {
    private func makeRepository() throws -> any WorkoutRepository {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(TrainingDataFactory.models), configurations: config)
        return TrainingDataFactory.makeWorkoutRepository(container: container)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["BENCH"] == "1"))
    func measure() async throws {
        let repo = try makeRepository()
        let exercises = (0..<40).map { _ in UUID() }
        let target = exercises[0]
        let day0 = DayDate(year: 2026, month: 1, day: 1)

        var t = Date()
        for i in 0..<200 {
            var w = Workout(id: UUID(), day: day0.adding(days: i),
                            startedAt: Date(), endedAt: Date().addingTimeInterval(3600))
            for slot in 0..<5 {
                let ex = exercises[(i * 5 + slot) % exercises.count]
                for s in 0..<5 {
                    w.appendSet(exerciseId: ex, weight: Weight(value: 50 + Double(s) * 2.5, unit: .kg), reps: 8)
                }
            }
            try await repo.save(w)
        }
        print(String(format: "[BENCH] seed 200 場 × 25 組 = %.2fs", Date().timeIntervalSince(t)))

        t = Date()
        let all = try await repo.finishedWorkouts()
        print(String(format: "[BENCH] finishedWorkouts() → %d 場, %.3fs", all.count, Date().timeIntervalSince(t)))

        t = Date()
        for _ in 0..<5 { _ = try await repo.finishedWorkouts() }
        print(String(format: "[BENCH] finishedWorkouts() ×5（訓練首頁每次 refresh）= %.3fs", Date().timeIntervalSince(t)))

        t = Date()
        for _ in 0..<5 { _ = try await repo.finishedWorkouts(limit: 60) }
        print(String(format: "[BENCH] finishedWorkouts(limit:60) ×5（首頁改用上限後）= %.3fs", Date().timeIntervalSince(t)))

        t = Date()
        let hist = try await repo.exerciseHistory(exerciseId: target)
        print(String(format: "[BENCH] exerciseHistory() → %d 組, %.3fs", hist.count, Date().timeIntervalSince(t)))

        t = Date()
        for ex in exercises.prefix(5) { _ = try await repo.exerciseHistory(exerciseId: ex) }
        print(String(format: "[BENCH] exerciseHistory() ×5（結束一場 5 動作的 PR 偵測）= %.3fs", Date().timeIntervalSince(t)))
    }
}
