import Foundation
import HistoryDomain
import SharedKernel

/// 單一動作歷史頁（04-history.md C 節：「依動作→單一動作」，圖表的唯一落點）的一個資料點：
/// 該場次的「代表組」（重量最重、同重量取次數最多的那一組）＋ 是否創新高。
public struct ExerciseTrendPoint: Identifiable, Equatable, Sendable {
    public let id: UUID   // session（workout）id
    public let day: DayDate
    public let weight: Weight
    public let reps: Int
    public let isPersonalRecord: Bool

    public init(id: UUID, day: DayDate, weight: Weight, reps: Int, isPersonalRecord: Bool) {
        self.id = id
        self.day = day
        self.weight = weight
        self.reps = reps
        self.isPersonalRecord = isPersonalRecord
    }
}

extension HistoryFormatting {
    /// PR 判定（Phase 0 定案）：同一動作，某場的代表組 weight×reps 若在「該重量下的次數」
    /// 或「該次數下的重量」任一維度創當時的新高，就算 PR。逐場依時間先後掃過一輪比較，
    /// 「新高」只跟*之前*的場次比，不含自己。
    ///
    /// - Parameter sessions: `sessions(exerciseId:)` 回傳的順序（新到舊）；這裡會反轉成時間序處理。
    static func trendPoints(for sessions: [HistoryExerciseSession]) -> [ExerciseTrendPoint] {
        // 一律用 Weight 本身當 key 與比較對象，不要退回 .value —— Weight 的雜湊與比較
        // 都已換算過單位，用 .value 會讓 100 lb 和 100 kg 變成同一格、並互相判成新高。
        var bestRepsAtWeight: [Weight: Int] = [:]
        var bestWeightAtReps: [Int: Weight] = [:]
        var points: [ExerciseTrendPoint] = []
        for session in sessions.reversed() {
            let doneSets = session.sets.filter { $0.status == .done }
            guard let best = doneSets.max(by: { ($0.weight, $0.reps) < ($1.weight, $1.reps) }) else { continue }
            let priorBestReps = bestRepsAtWeight[best.weight] ?? 0
            let priorBestWeight = bestWeightAtReps[best.reps] ?? Weight(value: 0, unit: .kg)
            let isPR = best.reps > priorBestReps || best.weight > priorBestWeight
            points.append(ExerciseTrendPoint(id: session.id, day: session.day, weight: best.weight, reps: best.reps, isPersonalRecord: isPR))
            bestRepsAtWeight[best.weight] = max(priorBestReps, best.reps)
            bestWeightAtReps[best.reps] = max(priorBestWeight, best.weight)
        }
        return points
    }
}
