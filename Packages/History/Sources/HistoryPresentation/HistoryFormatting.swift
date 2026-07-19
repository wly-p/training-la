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
