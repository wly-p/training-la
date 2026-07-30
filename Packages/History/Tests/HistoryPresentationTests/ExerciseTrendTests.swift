import Foundation
import HistoryDomain
import SharedKernel
import Testing

@testable import HistoryPresentation

struct ExerciseTrendTests {
    private func line(weight: Double, reps: Int) -> HistorySetLine {
        HistorySetLine(id: UUID(), setIndex: 0, weight: Weight(value: weight, unit: .kg), reps: reps, status: .done, targetWeight: nil, targetReps: nil)
    }

    private func session(day: DayDate, weight: Double, reps: Int) -> HistoryExerciseSession {
        HistoryExerciseSession(id: UUID(), day: day, sets: [line(weight: weight, reps: reps)])
    }

    /// `sessions(exerciseId:)` 的既有慣例：新到舊。
    @Test func firstSessionIsAlwaysAPersonalRecord() {
        let sessions = [session(day: DayDate(year: 2026, month: 7, day: 1), weight: 60, reps: 8)]

        let points = HistoryFormatting.trendPoints(for: sessions)

        #expect(points.count == 1)
        #expect(points[0].isPersonalRecord == true)
    }

    @Test func heavierWeightIsNewRecordEvenAtFewerReps() {
        // 新到舊：7/10 比 7/1 重，即使次數少也算 PR（該次數下的重量創新高）。
        let sessions = [
            session(day: DayDate(year: 2026, month: 7, day: 10), weight: 70, reps: 5),
            session(day: DayDate(year: 2026, month: 7, day: 1), weight: 60, reps: 8),
        ]

        let points = HistoryFormatting.trendPoints(for: sessions)

        #expect(points.map(\.isPersonalRecord) == [true, true])
    }

    @Test func sameWeightMoreRepsIsNewRecord() {
        let sessions = [
            session(day: DayDate(year: 2026, month: 7, day: 10), weight: 60, reps: 10),
            session(day: DayDate(year: 2026, month: 7, day: 1), weight: 60, reps: 8),
        ]

        let points = HistoryFormatting.trendPoints(for: sessions)

        // 回傳依時間序（舊到新）：points.first＝7/1（第一筆必是 PR），points.last＝7/10（同重量次數創新高）。
        #expect(points.first?.isPersonalRecord == true)
        #expect(points.last?.isPersonalRecord == true)
    }

    @Test func repeatingSameWeightAndRepsIsNotANewRecord() {
        let sessions = [
            session(day: DayDate(year: 2026, month: 7, day: 10), weight: 60, reps: 8),
            session(day: DayDate(year: 2026, month: 7, day: 1), weight: 60, reps: 8),
        ]

        let points = HistoryFormatting.trendPoints(for: sessions)

        // 回傳依時間序（舊到新）：7/1 先發生（PR），7/10 重複同樣的重量/次數，兩個維度都沒創新高。
        #expect(points.map(\.isPersonalRecord) == [true, false])
    }

    @Test func skippedSetsAreIgnoredWhenPickingSessionBest() {
        let day = DayDate(year: 2026, month: 7, day: 1)
        let skippedOnly = HistoryExerciseSession(id: UUID(), day: day, sets: [
            HistorySetLine(id: UUID(), setIndex: 0, weight: Weight(value: 100, unit: .kg), reps: 1, status: .skipped, targetWeight: nil, targetReps: nil),
        ])

        let points = HistoryFormatting.trendPoints(for: [skippedOnly])

        #expect(points.isEmpty)
    }
}
