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

    static func summary(_ spec: WorkoutSpec, name: (UUID) -> String, language: AppLanguage) -> String {
        summary(blocks: spec.blocks, name: name, language: language)
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

    /// 只列動作名（不帶組數），最多 `maxNames` 個，超出用「+N」——循環/長期匯入範本後的清單副標
    /// 用這個（設計稿 12a：`臥推 · 肩推 · 三頭下壓 +1`），跟範本清單自己的副標（含組數）不同。
    static func exerciseNamesSummary(_ spec: WorkoutSpec, name: (UUID) -> String, maxNames: Int = 3) -> String {
        exerciseNamesSummary(sets: spec.sets, name: name, maxNames: maxNames)
    }

    static func exerciseNamesSummary(sets: [PlanSet], name: (UUID) -> String, maxNames: Int = 3) -> String {
        let blocks = sets.planBlocks
        let shown = blocks.prefix(maxNames).map { name($0.exerciseId) }.joined(separator: " · ")
        let remaining = blocks.count - maxNames
        return remaining > 0 ? "\(shown) +\(remaining)" : shown
    }

    /// 循環課表副標「3 個範本 · 推日 → 拉日」：範本數（本地化單位）＋ workout 名以 → 串接（名稱是使用者資料）。
    /// 過長由列自身 `lineLimit(1)` 截斷。
    static func rotationSummary(_ rotation: Rotation, language: AppLanguage) -> String {
        let countFormat = language.localizedString("rotation.templateCount %lld", bundle: .module)
        let count = String(format: countFormat, rotation.workouts.count)
        guard !rotation.workouts.isEmpty else { return count }
        let names = rotation.workouts.map(\.name).joined(separator: " → ")
        return "\(count) · \(names)"
    }

    /// 長期課表副標「4 個範本 · 7 天週期」：有課天數 ＋ 週期天數（皆本地化）。
    static func programLibrarySummary(_ program: Program, language: AppLanguage) -> String {
        let format = language.localizedString("program.librarySummary %lld %lld", bundle: .module)
        return String(format: format, program.days.count, program.cycleLength)
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
