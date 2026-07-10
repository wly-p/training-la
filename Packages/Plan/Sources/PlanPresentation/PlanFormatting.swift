import Foundation
import PlanDomain
import SharedKernel

enum PlanFormatting {
    /// "臥推 4組 · 肩推 3組 · 三頭 3組"
    static func summary(_ planWorkout: PlanWorkout, name: (UUID) -> String) -> String {
        planWorkout.blocks
            .map { "\(name($0.exerciseId)) \($0.sets.count)組" }
            .joined(separator: " · ")
    }

    static func dayLabel(_ day: DayDate) -> String {
        var components = DateComponents()
        components.year = day.year; components.month = day.month; components.day = day.day
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        var suffix = ""
        if let date = Calendar(identifier: .gregorian).date(from: components) {
            let weekday = Calendar(identifier: .gregorian).component(.weekday, from: date)
            suffix = " (\(symbols[(weekday - 1) % 7]))"
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
