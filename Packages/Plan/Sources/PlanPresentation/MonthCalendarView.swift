import SharedKernel
import SwiftUI

/// 某天的排課標記（給月曆圓點）。
public enum DayMark: Equatable, Sendable {
    case scheduled   // 有未完成排課
    case done        // 當天排課都已完成
}

#if canImport(UIKit)
import UIKit

/// 原生 UICalendarView 月視圖的 SwiftUI 包裝。圓點用 decorationFor 畫；單選回呼更新選取日。
struct MonthCalendarView: UIViewRepresentable {
    @Binding var selectedDate: DayDate
    /// 目前有標記的日子（用來決定 reload 哪些格；含新舊聯集才能清掉消失的點）。
    let markedDates: Set<DayDate>
    /// 每天的標記；nil＝無點。
    let mark: (DayDate) -> DayMark?

    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = Calendar(identifier: .gregorian)
        view.delegate = context.coordinator
        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.setSelected(selectedDate.dateComponents, animated: false)
        view.selectionBehavior = selection
        context.coordinator.lastMarked = markedDates
        return view
    }

    func updateUIView(_ view: UICalendarView, context: Context) {
        context.coordinator.parent = self
        // reload 舊∪新，才能把已消失的點清掉。
        let union = context.coordinator.lastMarked.union(markedDates)
        if !union.isEmpty {
            view.reloadDecorations(forDateComponents: union.map(\.dateComponents), animated: false)
        }
        context.coordinator.lastMarked = markedDates
        if let selection = view.selectionBehavior as? UICalendarSelectionSingleDate,
           selection.selectedDate?.dayDate != selectedDate {
            selection.setSelected(selectedDate.dateComponents, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: MonthCalendarView
        var lastMarked: Set<DayDate> = []
        init(_ parent: MonthCalendarView) { self.parent = parent }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let day = dateComponents.dayDate, let mark = parent.mark(day) else { return nil }
            let color: UIColor = mark == .done ? .systemGreen : .systemGray
            return .default(color: color, size: .small)
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            if let day = dateComponents?.dayDate { parent.selectedDate = day }
        }
    }
}

extension DayDate {
    var dateComponents: DateComponents { DateComponents(year: year, month: month, day: day) }
}

extension DateComponents {
    var dayDate: DayDate? {
        guard let y = year, let m = month, let d = day else { return nil }
        return DayDate(year: y, month: m, day: d)
    }
}

#else

/// macOS fallback（swift test 用；正式 app 為 iOS）。
struct MonthCalendarView: View {
    @Binding var selectedDate: DayDate
    let markedDates: Set<DayDate>
    let mark: (DayDate) -> DayMark?
    var body: some View { Color.clear }
}

#endif
