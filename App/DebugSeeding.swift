#if DEBUG
import Foundation
import SharedKernel
import SpecDomain
import TrainingDomain

/// 只在 DEBUG build 生效的假資料產生器（體檢 D5）。
///
/// 為什麼需要：效能問題在第 1 週完全看不出來，要到第 2 年才明顯——
/// `save` 每記一組刪整棵重插（O(n²)）、`finishedWorkouts()` 每次都全量轉 domain、
/// 趨勢圖每列重算整條。沒有造資料的手段就無法驗證那些改動是否真的改善。
///
/// 用法（跟既有的 `--uitest-inmemory` / `--uitest-today` 同一個模式）：
/// ```
/// --debug-seed=200            # 200 場，每場預設 5 動作 × 5 組
/// --debug-seed=200x8x4        # 200 場，每場 8 動作 × 4 組
/// ```
/// 動作直接借用內建動作庫的固定 id（它們不進 SwiftData，是常駐清單），
/// 所以不用先建動作也能產生看得到名稱的紀錄。
///
/// **這裡產生的資料量是給「讀取路徑」用的**——歷史清單、趨勢圖、本週統計、
/// 能力值清單那些每次都全量掃描的地方（體檢 D2/D3/D4）。
/// 至於 `save` 每記一組刪整棵重插的 O(n²) 問題（D1），seeding 幫不上忙：
/// 它一場只 save 一次，而那個問題只在「逐組 append」時才會顯現。
/// 要驗 D1 得在訓練畫面連續記 30 組、量每次「完成此組」的耗時。
enum DebugSeeding {
    /// 解析出來的參數。
    struct Spec {
        var workoutCount: Int
        var exercisesPerWorkout: Int
        var setsPerExercise: Int

        var totalSets: Int { workoutCount * exercisesPerWorkout * setsPerExercise }
    }

    /// `--debug-seed=<場次>[x<動作數>x<每動作組數>]`；沒帶或格式不對回 nil。
    static func requestedSpec(arguments: [String] = CommandLine.arguments) -> Spec? {
        let prefix = "--debug-seed="
        guard let raw = arguments.first(where: { $0.hasPrefix(prefix) })?.dropFirst(prefix.count) else {
            return nil
        }
        let parts = raw.split(separator: "x").map { Int($0) }
        guard let first = parts.first, let workoutCount = first, workoutCount > 0 else { return nil }
        return Spec(
            workoutCount: workoutCount,
            exercisesPerWorkout: parts.count > 1 ? (parts[1] ?? 5) : 5,
            setsPerExercise: parts.count > 2 ? (parts[2] ?? 5) : 5
        )
    }

    /// 產生並寫入假場次。已經有紀錄就跳過——重開 App 不會愈疊愈多。
    ///
    /// 刻意涵蓋幾種會影響統計與 PR 判定的情境：混單位（kg／lb）、跳過的組、
    /// 逐週遞增的重量（讓趨勢圖與 PR 偵測有東西可算）。
    static func run(spec: Spec, repository: any WorkoutRepository, today: DayDate) async {
        guard (try? await repository.finishedWorkouts())?.isEmpty == true else {
            print("[DebugSeeding] store already has workouts, skipping")
            return
        }
        let catalog = OfficialExerciseCatalog.all
        guard !catalog.isEmpty else { return }

        let started = Date()
        for index in 0..<spec.workoutCount {
            // 最新的一場在今天，往回一天一場。
            let day = today.adding(days: -index)
            let startedAt = Date().addingTimeInterval(-Double(index) * 86_400)
            var workout = Workout(
                id: UUID(), day: day,
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(Double(45 + index % 30) * 60),
                overallFeeling: (index % 5) + 1
            )
            // 週次愈早重量愈輕，讓趨勢圖有斜率、PR 偵測有東西可比。
            let weekProgress = Double(spec.workoutCount - index) * 0.5
            for slot in 0..<spec.exercisesPerWorkout {
                let exercise = catalog[(index * spec.exercisesPerWorkout + slot) % catalog.count]
                for setIndex in 0..<spec.setsPerExercise {
                    // 每 7 場混一次 lb，確保換算與比較的路徑也被資料量壓到。
                    let unit: WeightUnit = index % 7 == 0 ? .lb : .kg
                    let base = 40.0 + Double(slot) * 5 + weekProgress + Double(setIndex) * 2.5
                    let value = unit == .lb ? (base * 2.20462262185).rounded() : base
                    workout.appendSet(
                        exerciseId: exercise.id,
                        weight: Weight(value: value, unit: unit),
                        reps: 8 - (setIndex % 3),
                        // 每 11 組跳過一組，讓「達標率」與熱身/跳過的過濾有東西可測。
                        status: (slot + setIndex) % 11 == 0 ? .skipped : .done
                    )
                }
            }
            try? await repository.save(workout)
        }
        let elapsed = Date().timeIntervalSince(started)
        print(String(
            format: "[DebugSeeding] seeded %d workouts / %d sets in %.1fs",
            spec.workoutCount, spec.totalSets, elapsed
        ))
    }
}
#endif
