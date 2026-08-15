import Foundation

/// `MonthDateStrip` 的日期數學。
///
/// 抽成純函式是因為這個 repo 的 View 測不到（沒有 preview、沒有 snapshot test），
/// 而格線與月名規則正好是唯一會算錯的地方。比照 `WheelGeometry` 的做法。
///
/// `calendar` 一律由外部注入 —— 這裡只做日期運算不取顯示字串，所以與 locale 無關；
/// 星期縮寫、月名那些「系統符號」在 View 那層處理。
public struct CalendarStripGeometry: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// 含 `date` 的那一週，7 天。週首依 `calendar.firstWeekday`。
    public func week(containing date: Date) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return days(from: interval.start, count: 7)
    }

    /// 含 `date` 的那個月的日期格，**固定 42 格（6 列）**，從含 1 號那一週的週首開始。
    ///
    /// 固定 6 列而不是依當月實際列數（4～6）決定高度：切月時區塊高度才不會跳，
    /// 下方的當日課表也就不會上下抽動。代價是短月會多畫一整列溢出日。
    public func monthGrid(containing date: Date) -> [Date] {
        guard let monthStart = startOfMonth(for: date),
              let interval = calendar.dateInterval(of: .weekOfYear, for: monthStart)
        else { return [] }
        return days(from: interval.start, count: 42)
    }

    /// `date` 是否落在 `month` 所屬月份之外 —— 也就是格線裡的上／下月溢出日。
    public func isOverflow(_ date: Date, in month: Date) -> Bool {
        !calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    /// 標題該顯示哪個月（handoff-22 G 節）。回傳該月 1 號。
    ///
    /// **選取日落在視窗內 → 用選取日的月；不在 → 用視窗裡佔天數較多的月。**
    ///
    /// 純視窗規則（第一天／最後一天／週四歸屬／單純多數決）都解不掉「今天是 8/1 週六」：
    /// 那一週是 7/26–8/1，六天在 7 月，多數決會讓使用者一開 App 就看到 7 月。
    /// 同一週因選取不同而顯示不同月不是 bug —— 週檢視的月名回答的是
    /// 「我正在看的這一天屬於哪個月」。7 天不可能平分，所以多數決永遠有唯一解。
    public func displayedMonth(window: [Date], selection: Date) -> Date {
        if let hit = window.first(where: { calendar.isDate($0, inSameDayAs: selection) }) {
            return startOfMonth(for: hit) ?? hit
        }
        var tally: [Date: Int] = [:]
        for day in window {
            guard let month = startOfMonth(for: day) else { continue }
            tally[month, default: 0] += 1
        }
        // 同票時取較早的月，讓結果穩定；7 天的視窗實際上不會同票。
        let winner = tally.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        }
        return winner?.key ?? (startOfMonth(for: selection) ?? selection)
    }

    /// 該月 1 號的 00:00。
    public func startOfMonth(for date: Date) -> Date? {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))
    }

    private func days(from start: Date, count: Int) -> [Date] {
        (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
