import Foundation

/// 星期幾（週一起算）。多週長期課表的週 grid 用得到。
public enum Weekday: Int, CaseIterable, Codable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    // 顯示用的星期名稱刻意不放這裡：`Calendar.shortWeekdaySymbols` 已經內建各語言的版本，
    // 自己維護一份只會多一個要翻譯的地方。索引換算是 `rawValue % 7`（本 enum 週一＝1、Calendar 週日＝0）。
}

extension DayDate {
    /// 以 Gregorian 曆算出星期幾。
    public var weekday: Weekday {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components) else { return .monday }
        // Calendar 的 .weekday：1=週日 … 7=週六 → 映射到本 enum（週一=1）。
        let w = calendar.component(.weekday, from: date)
        return Weekday(rawValue: (w + 5) % 7 + 1) ?? .monday
    }
}
