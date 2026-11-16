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

    /// 取出 `date` 落在哪一個日曆日。**年月日一律是西元（Gregorian）**，
    /// 傳入的 `calendar` 只借它的時區來決定「現在是哪一天」。
    ///
    /// 不能直接用 `calendar` 取年份：`Calendar.current` 跟著「設定 › 一般 › 語言與地區 › 行事曆」走，
    /// 台灣可以選民國曆、泰國預設佛曆、日本可以選和曆——那些裝置上 2026 年會拿到 115／2569／8。
    /// 而這個型別的其餘部分（`isoString` 儲存格式、`adding(days:)`、`weekdayNumber`、
    /// 各畫面的月曆與日期格式化）全部以西元解讀，於是「今天」會被存成西元 115 年：
    /// 今天的排課對不上月曆、星期幾算錯、本週統計整排是空的，而且錯的日期已經寫進資料庫。
    public init(_ date: Date, calendar: Calendar = .current) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
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
