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

    // MARK: - 達標判定（91-weight-model.md §6）

    private func setWithTarget(
        weight: Double, reps: Int, targetWeight: Double?, targetReps: Int?, status: WorkoutSetStatus = .done
    ) -> HistorySetLine {
        HistorySetLine(
            id: UUID(), setIndex: 0, weight: Weight(value: weight, unit: .kg), reps: reps, status: status,
            targetWeight: targetWeight.map { Weight(value: $0, unit: .kg) }, targetReps: targetReps
        )
    }

    @Test func achievedRequiresBothWeightAndRepsToMeetTarget() {
        #expect(HistoryFormatting.achieved(setWithTarget(weight: 60, reps: 8, targetWeight: 60, targetReps: 8)) == true)
        #expect(HistoryFormatting.achieved(setWithTarget(weight: 62.5, reps: 10, targetWeight: 60, targetReps: 8)) == true)
        #expect(HistoryFormatting.achieved(setWithTarget(weight: 60, reps: 6, targetWeight: 60, targetReps: 8)) == false)
        #expect(HistoryFormatting.achieved(setWithTarget(weight: 55, reps: 8, targetWeight: 60, targetReps: 8)) == false)
    }

    @Test func achievedIsNilWithoutTargetSnapshotOrWhenSkipped() {
        #expect(HistoryFormatting.achieved(setWithTarget(weight: 60, reps: 8, targetWeight: nil, targetReps: nil)) == nil)
        #expect(HistoryFormatting.achieved(setWithTarget(weight: 60, reps: 8, targetWeight: 60, targetReps: 8, status: .skipped)) == nil)
    }

    @Test func repsDeltaSignalsExceededOrShortfall() {
        #expect(HistoryFormatting.repsDelta(setWithTarget(weight: 60, reps: 10, targetWeight: 60, targetReps: 8)) == 2)
        #expect(HistoryFormatting.repsDelta(setWithTarget(weight: 60, reps: 6, targetWeight: 60, targetReps: 8)) == -2)
        #expect(HistoryFormatting.repsDelta(setWithTarget(weight: 60, reps: 8, targetWeight: nil, targetReps: nil)) == nil)
    }

    @Test func achievedSetCountExcludesSkippedAndUntargetedSets() {
        let blocks = [
            HistoryBlock(id: 0, exerciseName: "臥推", sets: [
                setWithTarget(weight: 60, reps: 8, targetWeight: 60, targetReps: 8),
                setWithTarget(weight: 60, reps: 6, targetWeight: 60, targetReps: 8),
                setWithTarget(weight: 60, reps: 8, targetWeight: 60, targetReps: 8, status: .skipped),
                setWithTarget(weight: 20, reps: 8, targetWeight: nil, targetReps: nil), // 臨時加練，無目標
            ]),
        ]
        let (achieved, total) = HistoryFormatting.achievedSetCount(blocks)
        #expect(achieved == 1)
        #expect(total == 2)   // 跳過的、沒有目標快照的都不進分母——那是「不適用」不是「沒達標」

        // 整場都是臨時加練（沒有任何目標快照）→ total 為 0，UI 該把「達標」徽章整條藏起來。
        let freeTraining = [HistoryBlock(id: 0, exerciseName: "深蹲", sets: [
            setWithTarget(weight: 20, reps: 8, targetWeight: nil, targetReps: nil),
        ])]
        #expect(HistoryFormatting.achievedSetCount(freeTraining).total == 0)
    }

    @Test func totalVolumeOnlyReturnsTargetWhenEverySetHasOne() {
        let complete = [HistoryBlock(id: 0, exerciseName: "臥推", sets: [
            setWithTarget(weight: 60, reps: 8, targetWeight: 60, targetReps: 8),
            setWithTarget(weight: 60, reps: 6, targetWeight: 60, targetReps: 8),
        ])]
        let (actual, target) = HistoryFormatting.totalVolume(complete)
        #expect(actual == 840)
        #expect(target == 960.0)

        let partial = [HistoryBlock(id: 0, exerciseName: "自由加練", sets: [
            setWithTarget(weight: 60, reps: 8, targetWeight: nil, targetReps: nil),
        ])]
        #expect(HistoryFormatting.totalVolume(partial).target == nil)
    }
}
