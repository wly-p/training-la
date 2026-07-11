import Foundation
import PlanDomain
import SharedKernel
import Testing

@testable import PlanPresentation

struct PlanFormattingTests {
    @Test func summaryJoinsExerciseNamesWithSetCounts() {
        let benchId = UUID()
        let squatId = UUID()
        let plan = PlanWorkout(id: UUID(), name: "推日", date: nil, orderIndex: 0, sets: [
            PlanSet(id: UUID(), exerciseId: benchId, exerciseIndex: 0, setIndex: 0, targetWeight: nil, targetReps: nil),
            PlanSet(id: UUID(), exerciseId: benchId, exerciseIndex: 0, setIndex: 1, targetWeight: nil, targetReps: nil),
            PlanSet(id: UUID(), exerciseId: squatId, exerciseIndex: 1, setIndex: 0, targetWeight: nil, targetReps: nil),
        ])
        let names: [UUID: String] = [benchId: "臥推", squatId: "深蹲"]

        let summary = PlanFormatting.summary(plan) { names[$0] ?? "?" }

        #expect(summary == "臥推 2組 · 深蹲 1組")
    }

    @Test func dayLabelIncludesMonthDayAndWeekday() {
        #expect(PlanFormatting.dayLabel(DayDate(year: 2026, month: 1, day: 1)) == "1/1 (四)")
        #expect(PlanFormatting.dayLabel(DayDate(year: 2026, month: 7, day: 12)) == "7/12 (日)")
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
