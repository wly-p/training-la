import Foundation
import PlanDomain
import SharedKernel

enum PlanFormatting {
    /// 繁中「臥推 4組 · 肩推 3組」、英文「Bench 4 sets · …」。動作名是 DB 資料；「組/sets」數量單位
    /// 依 `language` 本地化，用 `AppLanguage.localizedString` 明確解析（見該方法註解：
    /// `String(localized:locale:)` 不會依 locale 選語言，這裡不能用）。
    static func summary(_ planWorkout: PlanWorkout, name: (UUID) -> String, language: AppLanguage) -> String {
        summary(blocks: planWorkout.blocks, name: name, language: language)
    }

    static func templateSummary(_ template: WorkoutTemplate, name: (UUID) -> String, language: AppLanguage) -> String {
        summary(blocks: template.blocks, name: name, language: language)
    }

    private static func summary(blocks: [PlanBlock], name: (UUID) -> String, language: AppLanguage) -> String {
        blocks
            .map { block in
                let format = language.localizedString("plan.setCountUnit %lld", bundle: .module)
                let count = String(format: format, block.sets.count)
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
