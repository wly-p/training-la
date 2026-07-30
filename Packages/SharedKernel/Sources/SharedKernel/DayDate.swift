import Foundation

/// 純日曆日（無時間、無時區）。訓練日用這個而不是 `Date`，
/// 對齊 API 契約的 `format: date`（"yyyy-MM-dd"），避免時區換算把日期偏移一天。
public struct DayDate: Equatable, Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// 以使用者當前行事曆取出年月日。
    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    public init?(isoString: String) {
        let parts = isoString.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// "yyyy-MM-dd"，同時是儲存格式與 API wire format。
    public var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: DayDate, rhs: DayDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

// MARK: - 日曆算術（多週長期課表投影／補登用；固定 Gregorian，只算「日」不涉時區偏移）

extension DayDate {
    private static let gregorian = Calendar(identifier: .gregorian)

    private var gregorianDate: Date {
        Self.gregorian.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// 往後（負值往前）第 n 天。
    public func adding(days: Int) -> DayDate {
        DayDate(Self.gregorian.date(byAdding: .day, value: days, to: gregorianDate)!, calendar: Self.gregorian)
    }

    /// 從 self 到 other 相差幾天（other 較晚為正）。
    public func days(to other: DayDate) -> Int {
        Self.gregorian.dateComponents([.day], from: gregorianDate, to: other.gregorianDate).day!
    }

    /// 星期幾（1=週日...7=週六，對齊 `Calendar.component(.weekday:)`）。給「這週」相關 UI 判斷用
    /// （本週進度環等）。刻意不對外暴露底層 `Date` 換算本身（不加 public `asDate`）——
    /// 各 package 已各自有同名 private 擴充，重複加會撞名產生 "ambiguous use" 編譯錯誤。
    public var weekdayNumber: Int {
        Self.gregorian.component(.weekday, from: gregorianDate)
    }
}
