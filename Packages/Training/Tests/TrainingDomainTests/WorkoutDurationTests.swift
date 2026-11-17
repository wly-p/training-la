import Foundation
import SharedKernel
import Testing

@testable import TrainingDomain

/// `Workout.durationMinutes`：算得出且可信才回數字。
struct WorkoutDurationTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func workout(endAfter seconds: TimeInterval?) -> Workout {
        Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 27), startedAt: start,
                endedAt: seconds.map { start.addingTimeInterval($0) })
    }

    @Test func normalSessionReportsMinutes() {
        #expect(workout(endAfter: 65 * 60).durationMinutes == 65)
    }

    @Test func unfinishedOrMissingTimestampsIsNil() {
        #expect(workout(endAfter: nil).durationMinutes == nil)
        let noStart = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 27), endedAt: start)
        #expect(noStart.durationMinutes == nil)
    }

    /// 中斷後隔夜才結束：十幾個小時不是訓練時間，寧可不顯示。上限剛好那一刻仍算數。
    @Test func implausiblyLongSessionIsNil() {
        #expect(workout(endAfter: Workout.maxPlausibleDuration).durationMinutes == 360)
        #expect(workout(endAfter: Workout.maxPlausibleDuration + 1).durationMinutes == nil)
        #expect(workout(endAfter: 14 * 60 * 60).durationMinutes == nil)
    }

    /// 時鐘被往回調導致結束早於開始：不回負數也不硬湊成 0。
    @Test func negativeIntervalIsNil() {
        #expect(workout(endAfter: -60).durationMinutes == nil)
    }
}
