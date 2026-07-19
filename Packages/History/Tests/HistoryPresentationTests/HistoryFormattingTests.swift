import Foundation
import HistoryDomain
import SharedKernel
import Testing

@testable import HistoryPresentation

struct HistoryFormattingTests {
    private func line(weight: Weight, reps: Int) -> HistorySetLine {
        HistorySetLine(id: UUID(), setIndex: 0, weight: weight, reps: reps, status: .done, targetWeight: nil, targetReps: nil)
    }

    @Test func summaryReturnsEmptyStringForNoSets() {
        #expect(HistoryFormatting.summary(of: []) == "")
    }

    @Test func summaryCollapsesRepsWhenWeightIsSame() {
        let kg60 = Weight(value: 60, unit: .kg)
        let sets = [8, 8, 6].map { line(weight: kg60, reps: $0) }

        #expect(HistoryFormatting.summary(of: sets) == "60kg × 8, 8, 6")
    }

    @Test func summaryListsEachSetWhenWeightsDiffer() {
        let sets = [
            line(weight: Weight(value: 60, unit: .kg), reps: 8),
            line(weight: Weight(value: 65, unit: .kg), reps: 6),
        ]

        #expect(HistoryFormatting.summary(of: sets) == "60kg×8, 65kg×6")
    }

    @Test func feelingMapsValueToEmoji() {
        #expect(HistoryFormatting.feeling(1) == "😫")
        #expect(HistoryFormatting.feeling(3) == "😐")
        #expect(HistoryFormatting.feeling(5) == "💪")
    }

    @Test func feelingReturnsEmptyStringForNilOrUnknownValue() {
        #expect(HistoryFormatting.feeling(nil) == "")
        #expect(HistoryFormatting.feeling(99) == "")
    }

    @Test func dayLabelIncludesMonthDayAndLocalizedWeekday() {
        // 月/日固定；星期依 locale 取當地縮寫（不硬比字串，避免 OS 版本差異）
        let zh = HistoryFormatting.dayLabel(DayDate(year: 2026, month: 1, day: 1), locale: Locale(identifier: "zh-Hant"))
        #expect(zh.hasPrefix("1/1 ("))
        #expect(zh.hasSuffix(")"))
        // 英文 locale → 英文星期縮寫（2026-01-01 是週四）
        let en = HistoryFormatting.dayLabel(DayDate(year: 2026, month: 1, day: 1), locale: Locale(identifier: "en"))
        #expect(en.contains("Thu"))
    }
}
