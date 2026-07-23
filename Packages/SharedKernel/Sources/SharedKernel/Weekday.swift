import Foundation

/// 星期幾（週一起算）。多週長期課表的週 grid 用得到。
public enum Weekday: Int, CaseIterable, Codable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    /// 中文短名。
    public var shortName: String {
        switch self {
        case .monday: "週一"
        case .tuesday: "週二"
        case .wednesday: "週三"
        case .thursday: "週四"
        case .friday: "週五"
        case .saturday: "週六"
        case .sunday: "週日"
        }
    }
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
