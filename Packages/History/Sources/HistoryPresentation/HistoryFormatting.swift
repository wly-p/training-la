import Foundation
import HistoryDomain
import SharedKernel

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

    static let feelingEmojis = [1: "😫", 2: "😕", 3: "😐", 4: "🙂", 5: "💪"]

    static func feeling(_ value: Int?) -> String {
        guard let value else { return "" }
        return feelingEmojis[value] ?? ""
    }

    /// 2026-07-09 → "7/9 (三)"
    static func dayLabel(_ day: DayDate) -> String {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]
        var suffix = ""
        if let date = Calendar(identifier: .gregorian).date(from: components) {
            let weekday = Calendar(identifier: .gregorian).component(.weekday, from: date)
            suffix = " (\(weekdaySymbols[(weekday - 1) % 7]))"
        }
        return "\(day.month)/\(day.day)\(suffix)"
    }
}
