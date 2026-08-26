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

/// 熱身組不進趨勢圖也不進 PR 判定（B1）。
struct ExerciseTrendWarmupTests {
    private func line(weight: Double, reps: Int, isWarmup: Bool = false, setIndex: Int = 0) -> HistorySetLine {
        HistorySetLine(id: UUID(), setIndex: setIndex, weight: Weight(value: weight, unit: .kg),
                       reps: reps, status: .done, targetWeight: nil, targetReps: nil, isWarmup: isWarmup)
    }

    /// 熱身的 20kg 若被當成代表組，趨勢圖會出現一個往下的假谷。
    @Test func trendPointUsesTheWorkingSetNotTheWarmup() {
        let sessions = [
            HistoryExerciseSession(id: UUID(), day: DayDate(year: 2026, month: 8, day: 26), sets: [
                line(weight: 20, reps: 15, isWarmup: true),
                line(weight: 100, reps: 5, setIndex: 1),
            ])
        ]

        let points = HistoryFormatting.trendPoints(for: sessions)

        #expect(points.count == 1)
        #expect(points[0].weight == Weight(value: 100, unit: .kg))
        #expect(points[0].reps == 5)
    }

    /// 一整場只有熱身組＝那天沒有可畫的資料點，不該畫一個 20kg 的點。
    @Test func aWarmupOnlySessionProducesNoTrendPoint() {
        let sessions = [
            HistoryExerciseSession(id: UUID(), day: DayDate(year: 2026, month: 8, day: 26), sets: [
                line(weight: 20, reps: 15, isWarmup: true),
            ])
        ]

        #expect(HistoryFormatting.trendPoints(for: sessions).isEmpty)
    }
}
