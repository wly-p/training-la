import Foundation
import PlanDomain
import SharedKernel

enum PlanFormatting {
    /// 繁中「臥推 4組 · 肩推 3組」、英文「Bench 4 sets · …」。動作名是 DB 資料；「組/sets」數量單位
    /// 依 `locale` 本地化（String(localized:) 帶顯式 locale＝吃 app 覆寫的語言，非系統）。
    static func summary(_ planWorkout: PlanWorkout, name: (UUID) -> String, locale: Locale) -> String {
        planWorkout.blocks
            .map { block in
                let count = String(localized: "plan.setCountUnit \(block.sets.count)", bundle: .module, locale: locale)
                return "\(name(block.exerciseId)) \(count)"
            }
            .joined(separator: " · ")
    }

    /// 星期依 `locale` 取當地縮寫（由 View 傳 `@Environment(\.locale)`）。
    static func dayLabel(_ day: DayDate, locale: Locale) -> String {
        var components = DateComponents()
        components.year = day.year; components.month = day.month; components.day = day.day
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        var suffix = ""
        if let date = cal.date(from: components) {
            let formatter = DateFormatter()
            formatter.locale = locale
            let weekday = cal.component(.weekday, from: date)
            suffix = " (\(formatter.shortWeekdaySymbols[(weekday - 1) % 7]))"
        }
        return "\(day.month)/\(day.day)\(suffix)"
    }
}

extension DayDate {
    /// 與 Foundation Date 互轉（給 SwiftUI DatePicker 用）。
    public var asDate: Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }
}
