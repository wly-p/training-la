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

/// 寫入路徑的量測。跟 `ReadPathBenchmark` 同樣預設不跑：
///
/// ```
/// BENCH=1 swift test --filter WritePathBenchmark
/// ```
///
/// 量的是最熱的那條路：`ActiveWorkoutViewModel` 每記一組就 `saveProgress(workout)` 一次
/// （`ActiveWorkoutViewModel.swift:762`），所以一場 30 組 ＝ 30 次 `save`，
/// 而每次 save 傳進去的都是「整棵樹」。舊實作是刪整棵再重插，總寫入量 O(n²)。
///
/// **落地到磁碟量**，不是 in-memory：`isStoredInMemoryOnly` 會把真正的 I/O 成本藏掉，
/// 而刪除重插的代價正是在 I/O。裝置上跑的是磁碟。
///
/// 2026-08 在「庫裡已有 200 場 × 25 組」的前提下量到的基準：
/// | 呼叫 | 改前（刪除重插） | 改後（diff） |
/// |---|---|---|
/// | 一場 30 組，每組 save 一次 | 0.095s | 0.048s |
/// | 一場 60 組，每組 save 一次 | 0.340s | 0.148s |
/// | 最後一組那次 save 單獨（30 組） | 0.0045s | 0.0024s |
/// | 最後一組那次 save 單獨（60 組） | 0.0115s | 0.0042s |
///
/// 看的是**成長曲線**：組數翻倍若耗時變四倍，就是 O(n²) 的簽名。
/// 改前 30→60 組耗時 3.6 倍、單次 save 2.6 倍；改後分別是 3.1 倍與 1.75 倍。
///
/// 改後單次 save 幾乎持平（1.75 倍而非 2.6 倍）＝**磁碟寫入已經是 O(1)**。
/// 總耗時還帶一點成長，是因為每次 save 仍要 fetch 整棵並逐組比對——那是記憶體裡的掃描，
/// 不是 I/O。要再往下砍就得讓 protocol 長出 append 專用的方法，那是另一個題目。
struct WritePathBenchmark {
    /// 每次量測用一個全新的磁碟檔，量完刪掉——共用檔案會讓第二次量測面對前一次的殘留。
    private func withDiskRepository(
        _ body: (any WorkoutRepository) async throws -> Void
    ) async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bench-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let container = try ModelContainer(
            for: Schema(TrainingDataFactory.models),
            configurations: ModelConfiguration(url: url)
        )
        try await body(TrainingDataFactory.makeWorkoutRepository(container: container))
    }

    /// 一場 `setCount` 組的訓練，每記一組落地一次。回傳（總耗時, 最後一次 save 的耗時）。
    private func measureLiveSession(
        repo: any WorkoutRepository, exercises: [UUID], day: DayDate, setCount: Int
    ) async throws -> (total: Double, lastSave: Double) {
        var live = Workout(id: UUID(), day: day, startedAt: Date())
        let start = Date()
        var lastSave = 0.0
        for i in 0..<setCount {
            live.appendSet(
                exerciseId: exercises[i / 5],
                weight: Weight(value: 60 + Double(i % 5) * 2.5, unit: .kg), reps: 5
            )
            let saveStart = Date()
            try await repo.save(live)
            lastSave = Date().timeIntervalSince(saveStart)
        }
        // 落地結果要正確，不然量的是壞掉的實作。
        let readBack = try await repo.get(id: live.id)
        #expect(readBack?.sets.count == setCount)
        return (Date().timeIntervalSince(start), lastSave)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["BENCH"] == "1"))
    func measure() async throws {
        let exercises = (0..<40).map { _ in UUID() }
        let day0 = DayDate(year: 2026, month: 1, day: 1)

        for setCount in [30, 60] {
            try await withDiskRepository { repo in
                // 鋪底：跟讀取量測同一份資料量，讓 save 面對的是真實大小的庫而不是空庫。
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

                let result = try await measureLiveSession(
                    repo: repo, exercises: exercises, day: day0.adding(days: 201), setCount: setCount
                )
                print(String(
                    format: "[BENCH] 一場 %d 組、每組 save 一次 = %.3fs（最後一組那次 %.4fs）",
                    setCount, result.total, result.lastSave
                ))
            }
        }
    }
}
