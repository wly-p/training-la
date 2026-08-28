import Foundation
import HistoryDomain
import SharedKernel
import SwiftUI

enum HistoryFormatting {
    /// 一場某動作的摘要："60kg × 8, 8, 6"（同重量）或逐組列出（混重量）。
    static func summary(of sets: [HistorySetLine]) -> String {
        guard let first = sets.first else { return "" }
        if sets.allSatisfy({ $0.weight == first.weight }) {
            let reps = sets.map { "\($0.reps)" }.joined(separator: ", ")
            return "\(first.weight.displayString) × \(reps)"
        }
        return sets.map { "\($0.weight.displayString)×\($0.reps)" }.joined(separator: ", ")
    }

    /// 組狀態標籤的 String Catalog key（View 用 `localText(_:)` 映射多語；繁中值見 Localizable.xcstrings）。
    static func statusLabel(_ status: WorkoutSetStatus) -> LocalizedStringKey {
        switch status {
        case .done: "history.status.done"
        case .skipped: "history.status.skipped"
        case .interrupted: "history.status.interrupted"
        }
    }

    static let feelingEmojis = [1: "😫", 2: "😕", 3: "😐", 4: "🙂", 5: "💪"]

    static func feeling(_ value: Int?) -> String {
        guard let value else { return "" }
        return feelingEmojis[value] ?? ""
    }

    /// 逐組對照的達標判定（91-weight-model.md §6）：實際 >= 目標重量 && 實際 >= 目標次數。
    /// 沒有目標快照（臨時加練，或跳過沒做）＝nil，不顯示任何符號——那是資訊不是錯誤。
    /// 熱身組回 nil（同 Training 側的 `FinishSummaryFormatting.achieved`）：沒有達標的概念。
    static func achieved(_ set: HistorySetLine) -> Bool? {
        guard set.status == .done, !set.isWarmup,
              let targetWeight = set.targetWeight, let targetReps = set.targetReps else {
            return nil
        }
        return set.weight >= targetWeight && set.reps >= targetReps
    }

    /// 次數差異（達標時不用顯示）：正＝超出、負＝未達，給逐組對照表的「+1／−1」符號用。
    static func repsDelta(_ set: HistorySetLine) -> Int? {
        guard set.status == .done, let targetReps = set.targetReps else { return nil }
        return set.reps - targetReps
    }

    /// 一場的達標組數／總組數。只算「能判定達標與否」的組——沒有目標快照的臨時加練
    /// 不進分母：那不是「沒達標」，是「不適用」，混進去會讓「達標 0/1」這種假訊號出現。
    /// 跳過的也不進分母（見 01-training.md 跳過≠移除，`achieved` 對 `.skipped` 已回 nil）。
    static func achievedSetCount(_ blocks: [HistoryBlock]) -> (achieved: Int, total: Int) {
        let evaluable = blocks.flatMap(\.sets).filter { achieved($0) != nil }
        let achievedCount = evaluable.filter { achieved($0) == true }.count
        return (achievedCount, evaluable.count)
    }

    /// 總量（實際 kg×次數）；目標總量只在「每一組都有目標快照」時才給，否則 nil
    /// （只要有一組是 `relativeToLast` 查不到歷史或臨時加練，總量在投影/紀錄當下就不完整算不出來）。
    static func totalVolume(_ blocks: [HistoryBlock]) -> (actual: Double, target: Double?) {
        // 一律換算成公斤再加總——這種聚合 Comparable 幫不上，混單位相加的數字沒有意義。
        // 熱身組不計入（同 Training 側）。
        let doneSets = blocks.flatMap(\.sets).filter { $0.status == .done && !$0.isWarmup }
        let actual = doneSets.reduce(0.0) { $0 + $1.weight.kilograms * Double($1.reps) }
        let targets = doneSets.compactMap { set -> Double? in
            guard let tw = set.targetWeight, let tr = set.targetReps else { return nil }
            return tw.kilograms * Double(tr)
        }
        let target = targets.count == doneSets.count && !targets.isEmpty ? targets.reduce(0, +) : nil
        return (actual, target)
    }

    /// 整數不帶小數、其餘去掉多餘 0（4280.0→"4280"、4280.5→"4280.5"）。
    static func formatNumber(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }

    /// 列表列左側索引欄的星期縮寫（「一」「二」...／"Mon""Tue"...），單獨給日期數字旁配色用。
    static func weekdayAbbrev(_ day: DayDate, locale: Locale) -> String {
        var components = DateComponents()
        components.year = day.year; components.month = day.month; components.day = day.day
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        guard let date = cal.date(from: components) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = locale
        let weekday = cal.component(.weekday, from: date)
        return formatter.veryShortWeekdaySymbols[(weekday - 1) % 7]
    }

    /// 月份分組標題的月份數字（「7 月」）。`locale` 由 View 傳 `@Environment(\.locale)`，
    /// 才會跟著 app 的語言設定走而不是手機語系。
    static func monthLabel(month: Int, locale: Locale) -> String {
        String(format: localString("history.month %lld", locale), month)
    }

    /// 2026-07-09 → 繁中「7/9 (週三)」、英文「7/9 (Wed)」。星期依傳入的 `locale` 取當地縮寫，
    /// 由 View 傳 `@Environment(\.locale)`，切語言即時更新。
    static func dayLabel(_ day: DayDate, locale: Locale) -> String {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        var suffix = ""
        if let date = cal.date(from: components) {
            let formatter = DateFormatter()
            formatter.locale = locale
            let weekday = cal.component(.weekday, from: date) // 1=Sunday
            suffix = " (\(formatter.shortWeekdaySymbols[(weekday - 1) % 7]))"
        }
        return "\(day.month)/\(day.day)\(suffix)"
    }
}
