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

    // MARK: - 週

    @Test func weekRunsSundayToSaturday() {
        let week = geo.week(containing: day("2026-08-01"))   // 8/1 是週六
        #expect(week.count == 7)
        #expect(iso(week.first!) == "2026-07-26")            // 週日
        #expect(iso(week.last!) == "2026-08-01")
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

    // MARK: - 收合態月名（handoff-22 G）

    @Test func selectionInsideTheWindowWinsOverTheMajorityMonth() {
        // 這一格是整條規則存在的理由：今天是 8/1（週六），那一週 7/26–8/1 有六天在 7 月。
        // 用單純多數決的話，使用者一打開 App 就會看到「7 月」。
        let window = geo.week(containing: day("2026-08-01"))
        #expect(iso(geo.displayedMonth(window: window, selection: day("2026-08-01"))) == "2026-08-01")
    }

    @Test func sameWindowShowsJulyWhenAJulyDayIsSelected() {
        // 同一週、選 7/28 → 7 月。同一週因選取不同而顯示不同月是刻意的：
        // 週檢視的月名回答的是「我正在看的這一天屬於哪個月」。
        let window = geo.week(containing: day("2026-08-01"))
        #expect(iso(geo.displayedMonth(window: window, selection: day("2026-07-28"))) == "2026-07-01")
    }

    @Test func selectionOutsideTheWindowFallsBackToTheMajorityMonth() {
        // 滑走之後選取日不在視窗內，改用多數月。
        let window = geo.week(containing: day("2026-08-05"))   // 8/2–8/8，全都在 8 月
        #expect(iso(geo.displayedMonth(window: window, selection: day("2026-08-01"))) == "2026-08-01")
    }

    @Test func majorityMonthCrossesTheYearBoundary() {
        // 12/27–1/2：五天在 2026-12、兩天在 2027-01，選取日滑得很遠。
        // 年份要跟著月名一起跳到 2026。
        let window = geo.week(containing: day("2026-12-30"))
        #expect(iso(window.first!) == "2026-12-27")
        #expect(iso(window.last!) == "2027-01-02")
        #expect(iso(geo.displayedMonth(window: window, selection: day("2026-08-15"))) == "2026-12-01")
    }

    @Test func selectionInsideAYearCrossingWindowStillWins() {
        // 同一個跨年視窗，選取日落在 1/1 → 顯示 2027-01，即使 12 月佔的天數比較多。
        let window = geo.week(containing: day("2026-12-30"))
        #expect(iso(geo.displayedMonth(window: window, selection: day("2027-01-01"))) == "2027-01-01")
    }

    @Test func monthNameIsStableWhenBrowsingAwayAndBack() {
        // 滑走再滑回來月名要回到原值，不能抖。
        let home = geo.week(containing: day("2026-08-01"))
        let selection = day("2026-08-01")
        let before = geo.displayedMonth(window: home, selection: selection)
        let away = geo.week(containing: day("2026-08-05"))
        _ = geo.displayedMonth(window: away, selection: selection)
        #expect(geo.displayedMonth(window: home, selection: selection) == before)
    }
}
