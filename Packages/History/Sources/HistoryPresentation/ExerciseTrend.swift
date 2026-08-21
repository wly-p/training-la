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
    /// 逐場算出趨勢點與 PR 標記。判定規則見 `SharedKernel.PersonalRecordRule`——
    /// 原本這裡跟 Training 的 `DetectPersonalRecords` 各留一份，兩份規則悄悄長歪了
    /// （這裡拿 0 當基準、那裡要求維度先前出現過），同一場可能在趨勢圖有獎盃、
    /// 在完成摘要卻沒有（體檢 P4-4）。現在兩邊走同一支。
    ///
    /// - Parameter sessions: `sessions(exerciseId:)` 回傳的順序（新到舊）；這裡會反轉成時間序處理，
    ///   因為「新高」只能跟**它之前**的場次比。
    static func trendPoints(for sessions: [HistoryExerciseSession]) -> [ExerciseTrendPoint] {
        var seen: [PersonalRecordRule.Performance] = []
        var points: [ExerciseTrendPoint] = []
        for session in sessions.reversed() {
            let doneSets = session.sets.filter { $0.status == .done }
            guard let best = PersonalRecordRule.representative(
                of: doneSets.map { .init(weight: $0.weight, reps: $0.reps) }
            ) else { continue }
            let isPR = PersonalRecordRule.evaluate(best, against: seen) != nil
            points.append(ExerciseTrendPoint(
                id: session.id, day: session.day,
                weight: best.weight, reps: best.reps, isPersonalRecord: isPR
            ))
            // 只累積代表組：判定問的是「有沒有超越過往最好的表現」，
            // 把每一組都塞進去不會改變 max，只是多花時間。
            seen.append(best)
        }
        return points
    }
}
