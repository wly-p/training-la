import Foundation
import PlanDomain
import SharedKernel
import Testing

@testable import PlanPresentation

struct PlanFormattingTests {
    @Test func summaryJoinsExerciseNamesWithSetCounts() {
        let benchId = UUID()
        let squatId = UUID()
        let plan = PlanWorkout(id: UUID(), name: "推日", date: DayDate(year: 2026, month: 7, day: 9), orderIndex: 0, sets: [
            PlanSet(id: UUID(), exerciseId: benchId, exerciseIndex: 0, setIndex: 0, targetWeight: nil, targetReps: nil),
            PlanSet(id: UUID(), exerciseId: benchId, exerciseIndex: 0, setIndex: 1, targetWeight: nil, targetReps: nil),
            PlanSet(id: UUID(), exerciseId: squatId, exerciseIndex: 1, setIndex: 0, targetWeight: nil, targetReps: nil),
        ])
        let names: [UUID: String] = [benchId: "臥推", squatId: "深蹲"]

        // 註：swift test（SwiftPM CLI）不編譯 String Catalog，這裡不驗「組/sets」本地化字（那由 app 端
        // PlanScheduleUITests 驗，見 testPlanRowLocalizesSetCountUnit），只驗組合邏輯：兩個動作名、
        // 依序、以 " · " 相連。
        let summary = PlanFormatting.summary(plan, name: { names[$0] ?? "?" }, language: .zhHant)
        #expect(summary.contains("臥推"))
        #expect(summary.contains("深蹲"))
        #expect(summary.hasPrefix("臥推 "))
        #expect(summary.contains(" · 深蹲 "))
    }

    @Test func dayLabelIncludesMonthDayAndLocalizedWeekday() {
        let zh = PlanFormatting.dayLabel(DayDate(year: 2026, month: 1, day: 1), locale: Locale(identifier: "zh-Hant"))
        #expect(zh.hasPrefix("1/1 ("))
        #expect(zh.hasSuffix(")"))
        let en = PlanFormatting.dayLabel(DayDate(year: 2026, month: 1, day: 1), locale: Locale(identifier: "en"))
        #expect(en.contains("Thu"))
    }

    @Test func dayDateAsDateRoundTripsThroughGregorianCalendar() {
        let day = DayDate(year: 2026, month: 7, day: 9)
        let date = day.asDate

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        #expect(components.year == 2026)
        #expect(components.month == 7)
        #expect(components.day == 9)
    }
}
