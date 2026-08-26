import Foundation
import TrainingDomain

/// 完成摘要（13a）的純函式邏輯：達標判定／總量／目標總量。跟 History（Phase 4）對
/// `達標 = 實際 >= 目標重量 && 實際 >= 目標次數` 是同一條規則（91-weight-model.md §6），
/// 但兩個 package 不互相 import Presentation，各自留一份薄的版本，不強行共用。
enum FinishSummaryFormatting {
    /// 這組有沒有達標；只有「已完成且有目標快照」的組才有定義——沒有目標快照（自由加練）
    /// 或 `.skipped` 都不列入判定，回 nil（呼叫端用 `compactMap` 自然排除，不用特別過濾）。
    /// 熱身組回 nil：它沒有「達標」的概念，混進分母會出現「達標 3/6 組」這種假訊號。
    static func achieved(_ set: WorkoutSet) -> Bool? {
        guard set.status == .done, !set.isWarmup,
              let targetWeight = set.targetWeight, let targetReps = set.targetReps
        else { return nil }
        return set.weight >= targetWeight && set.reps >= targetReps
    }

    /// 「達標 X/Y 組」：分母只算「真的被判定過」的組數，free 加練/跳過都不計入。
    static func achievedSetCount(_ sets: [WorkoutSet]) -> (achieved: Int, total: Int) {
        let judged = sets.compactMap(achieved)
        return (judged.filter { $0 }.count, judged.count)
    }

    /// 實際總量（公斤；只算 `.done` 的組，跳過的組沒有真的舉起來不算）。
    /// 加總前一律換算成公斤——這種聚合 `Comparable` 幫不上，混單位相加的數字沒有意義。
    /// 熱身組不計入：熱身的 20kg × 15 下混進去會讓進步曲線失真。
    static func totalVolume(_ sets: [WorkoutSet]) -> Double {
        sets.filter { $0.status == .done && !$0.isWarmup }
            .reduce(0) { $0 + $1.weight.kilograms * Double($1.reps) }
    }

    /// 目標總量（公斤）：只加總「有目標快照」的組（照課表的部分），自由加練沒有目標、不計入。
    static func targetVolume(_ sets: [WorkoutSet]) -> Double {
        sets.compactMap { set -> Double? in
            guard !set.isWarmup,
                  let targetWeight = set.targetWeight, let targetReps = set.targetReps else { return nil }
            return targetWeight.kilograms * Double(targetReps)
        }
        .reduce(0, +)
    }

    /// 每個動作的「這場做了什麼」摘要：組數、重量區間（60→80 kg；同重量只顯示一個數字）、
    /// 是不是整個動作都達標（沒有可判定的組時回 nil，UI 用空圈而非誤導的勾號）。
    struct ExerciseSummary: Identifiable {
        let exerciseId: UUID
        let name: String
        let setCount: Int
        let weightRange: String
        let allAchieved: Bool?
        var id: UUID { exerciseId }
    }

    static func exerciseSummaries(_ blocks: [ExerciseBlock], nameLookup: (UUID) -> String) -> [ExerciseSummary] {
        blocks.map { block in
            // 取 Weight 本身的 min/max（已換算單位），不要拿 .value 比 —— 混單位時
            // 用 .value 挑出來的「最輕/最重」會是錯的。
            // 重量區間也不算熱身組：顯示「20→100 kg」會讓人以為那天做了很寬的遞增。
            let workingSets = block.sets.filter { !$0.isWarmup }
            let weights = workingSets.map(\.weight)
            let range: String
            if let min = weights.min(), let max = weights.max() {
                range = min == max
                    ? WeightDisplay.value(min.value)
                    : "\(WeightDisplay.value(min.value))→\(WeightDisplay.value(max.value))"
            } else {
                range = "—"
            }
            let judged = workingSets.compactMap(achieved)
            let allAchieved: Bool? = judged.isEmpty ? nil : judged.allSatisfy { $0 }
            return ExerciseSummary(
                exerciseId: block.exerciseId, name: nameLookup(block.exerciseId),
                setCount: workingSets.count, weightRange: range, allAchieved: allAchieved
            )
        }
    }
}
