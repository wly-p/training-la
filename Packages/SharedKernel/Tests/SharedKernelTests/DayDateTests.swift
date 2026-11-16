import Foundation
import Testing

@testable import SharedKernel

struct DayDateTests {
    @Test func initFromComponents() {
        let day = DayDate(year: 2026, month: 7, day: 9)
        #expect(day.year == 2026)
        #expect(day.month == 7)
        #expect(day.day == 9)
    }

    @Test func weekdayMapsMondayFirst() {
        // 2026-07-23 是週四；週一 2026-07-20、週日 2026-07-26
        #expect(DayDate(year: 2026, month: 7, day: 20).weekday == .monday)
        #expect(DayDate(year: 2026, month: 7, day: 23).weekday == .thursday)
        #expect(DayDate(year: 2026, month: 7, day: 26).weekday == .sunday)
    }

    @Test func initFromDateExtractsCalendarComponents() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 15
        components.hour = 23
        let date = calendar.date(from: components)!

        let day = DayDate(date, calendar: calendar)

        #expect(day == DayDate(year: 2026, month: 3, day: 15))
    }

    /// 裝置行事曆不是西元（民國曆、佛曆、和曆）時，年份仍然要是西元。
    /// 原本直接拿 `Calendar.current` 的年份，民國曆裝置上「今天」會被存成西元 115 年。
    @Test(arguments: [Calendar.Identifier.republicOfChina, .buddhist, .japanese, .gregorian])
    func initFromDateIsAlwaysGregorian(identifier: Calendar.Identifier) {
        let taipei = TimeZone(identifier: "Asia/Taipei")!
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = taipei
        let date = gregorian.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 9))!

        var deviceCalendar = Calendar(identifier: identifier)
        deviceCalendar.timeZone = taipei

        #expect(DayDate(date, calendar: deviceCalendar) == DayDate(year: 2026, month: 11, day: 16))
    }

    /// 「哪一天」跟著傳入行事曆的時區走：同一個瞬間在台北已經是隔天。
    @Test func initFromDateUsesCalendarTimeZone() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let date = utc.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 20))!

        var taipei = Calendar(identifier: .republicOfChina)
        taipei.timeZone = TimeZone(identifier: "Asia/Taipei")!

        #expect(DayDate(date, calendar: utc) == DayDate(year: 2026, month: 11, day: 16))
        #expect(DayDate(date, calendar: taipei) == DayDate(year: 2026, month: 11, day: 17))
    }

    @Test func isoStringRoundTrips() {
        let day = DayDate(year: 2026, month: 1, day: 5)
        #expect(day.isoString == "2026-01-05")
        #expect(DayDate(isoString: day.isoString) == day)
    }

    @Test func initFromIsoStringRejectsMalformedInput() {
        #expect(DayDate(isoString: "2026-01") == nil)
        #expect(DayDate(isoString: "2026-01-05-extra") == nil)
        #expect(DayDate(isoString: "abcd-01-05") == nil)
    }

    @Test func comparableOrdersByYearThenMonthThenDay() {
        let earlier = DayDate(year: 2026, month: 7, day: 9)
        let laterDay = DayDate(year: 2026, month: 7, day: 10)
        let laterMonth = DayDate(year: 2026, month: 8, day: 1)
        let laterYear = DayDate(year: 2027, month: 1, day: 1)

        #expect(earlier < laterDay)
        #expect(laterDay < laterMonth)
        #expect(laterMonth < laterYear)
        #expect(!(laterYear < earlier))
    }

    @Test func equatableAndHashable() {
        let a = DayDate(year: 2026, month: 7, day: 9)
        let b = DayDate(year: 2026, month: 7, day: 9)
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
    }
}
