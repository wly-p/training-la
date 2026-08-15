import Foundation
import Testing

@testable import DesignSystem

/// 月曆條的日期數學。日期一律用固定的 2026 年份寫死，不讀時鐘。
struct CalendarStripGeometryTests {
    /// 週日起始（設計稿的星期標頭是「日 一 二 三 四 五 六」）。
    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }

    private let geo = CalendarStripGeometry(calendar: calendar)

    private func day(_ iso: String) -> Date {
        let parts = iso.split(separator: "-").map { Int($0)! }
        return Self.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
    }

    private func iso(_ date: Date) -> String {
        let c = Self.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    // MARK: - 月網格

    @Test func monthGridIsAlwaysFortyTwoCells() {
        // 2026-08：1 號是週六，所以格線從上個月的 7/26 開始，到 9/5 結束。
        let grid = geo.monthGrid(containing: day("2026-08-15"))
        #expect(grid.count == 42)
        #expect(iso(grid.first!) == "2026-07-26")
        #expect(iso(grid.last!) == "2026-09-05")
    }

    @Test func shortMonthStillGetsSixRows() {
        // 2026-02：1 號正好是週日、28 天，剛好四週。固定 6 列的意義就在這裡——
        // 依實際列數決定高度的話，這個月會比別的月矮兩列，切月時版面會跳。
        let grid = geo.monthGrid(containing: day("2026-02-10"))
        #expect(grid.count == 42)
        #expect(iso(grid.first!) == "2026-02-01")
        #expect(iso(grid.last!) == "2026-03-14")
    }

    @Test func overflowDaysAreTheOnesOutsideTheMonth() {
        let august = day("2026-08-15")
        #expect(geo.isOverflow(day("2026-07-31"), in: august))
        #expect(geo.isOverflow(day("2026-09-01"), in: august))
        #expect(!geo.isOverflow(day("2026-08-01"), in: august))
    }
}
