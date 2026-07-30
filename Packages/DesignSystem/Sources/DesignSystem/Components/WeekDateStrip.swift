import SwiftUI

/// 模板 9：週日期條（取代原生月曆）。
/// 7 欄，每欄：星期縮寫 10pt `neutral-500` → 40pt 圓（日期 16pt Caprasimo）→ 5pt 圓點。
///  - 今天 = `accent` 實心 + `bg` 字
///  - 有排課 = `sage` 點
///  - 已完成 = 赭紅實心 ＋ 白勾
///
/// 左右滑動換週。
public struct WeekDateStrip: View {
    /// 某一天的標記狀態。
    public enum DayMark: Sendable {
        case none        // 無排課
        case scheduled   // 有排課（sage 點）
        case completed   // 已完成（赭紅實心＋白勾）
    }

    @Binding private var selectedDate: Date
    private let mark: (Date) -> DayMark
    private let calendar: Calendar

    @State private var weekOffset: Int = 0

    public init(
        selectedDate: Binding<Date>,
        calendar: Calendar = .current,
        mark: @escaping (Date) -> DayMark
    ) {
        self._selectedDate = selectedDate
        self.calendar = calendar
        self.mark = mark
    }

    private var days: [Date] {
        let base = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: selectedDate) ?? selectedDate
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: base) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                column(for: day)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, TLSpace.page)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { g in
                    if g.translation.width < 0 { withAnimation(.easeOut(duration: 0.2)) { weekOffset += 1 } }
                    else if g.translation.width > 0 { withAnimation(.easeOut(duration: 0.2)) { weekOffset -= 1 } }
                }
        )
    }

    private func column(for day: Date) -> some View {
        let isToday = calendar.isDateInToday(day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let m = mark(day)
        let dayNumber = calendar.component(.day, from: day)

        return VStack(spacing: 6) {
            Text(weekdaySymbol(for: day))
                .font(TLFont.zh(10, .semibold))
                .textCase(.uppercase)
                .foregroundStyle(TLColor.neutral500)

            ZStack {
                if m == .completed || isToday {
                    Circle().fill(TLColor.accent)
                } else if isSelected {
                    Circle().strokeBorder(TLColor.accent300, lineWidth: 1.5)
                }
                if m == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TLColor.bg)
                } else {
                    Text("\(dayNumber)")
                        .font(TLFont.display(16))
                        .foregroundStyle(isToday ? TLColor.bg : TLColor.text)
                }
            }
            .frame(width: 40, height: 40)

            Circle()
                .fill(m == .scheduled ? TLColor.sage : Color.clear)
                .frame(width: 5, height: 5)
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedDate = day }
    }

    private func weekdaySymbol(for day: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = calendar.locale ?? .current
        let idx = calendar.component(.weekday, from: day) - 1
        return f.shortWeekdaySymbols[idx]
    }
}
