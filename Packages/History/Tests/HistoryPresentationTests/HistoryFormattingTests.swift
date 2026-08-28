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
        #expect(HistoryFormatting.summary(of: [], in: .kg) == "")
    }

    @Test func summaryCollapsesRepsWhenWeightIsSame() {
        let kg60 = Weight(value: 60, unit: .kg)
        let sets = [8, 8, 6].map { line(weight: kg60, reps: $0) }

        #expect(HistoryFormatting.summary(of: sets, in: .kg) == "60kg × 8, 8, 6")
    }

    @Test func summaryListsEachSetWhenWeightsDiffer() {
        let sets = [
            line(weight: Weight(value: 60, unit: .kg), reps: 8),
            line(weight: Weight(value: 65, unit: .kg), reps: 6),
        ]

        #expect(HistoryFormatting.summary(of: sets, in: .kg) == "60kg×8, 65kg×6")
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

/// 熱身組不進 History 側的統計與趨勢圖（B1）。
///
/// `HistoryFormatting` 與 Training 的 `FinishSummaryFormatting` 是兩份平行實作
/// （體檢查證過），所以同一條規則兩邊都要有測試——只改一邊的話，同一場訓練
/// 在完成摘要與歷史頁會顯示不同的總量。
struct HistoryWarmupExclusionTests {
    private func line(
        weight: Double, reps: Int, target: Double? = nil, targetReps: Int? = nil,
        isWarmup: Bool = false, setIndex: Int = 0
    ) -> HistorySetLine {
        HistorySetLine(
            id: UUID(), setIndex: setIndex,
            weight: Weight(value: weight, unit: .kg), reps: reps, status: .done,
            targetWeight: target.map { Weight(value: $0, unit: .kg) }, targetReps: targetReps,
            isWarmup: isWarmup
        )
    }

    private func block(_ sets: [HistorySetLine]) -> HistoryBlock {
        HistoryBlock(id: 0, exerciseName: "臥推", sets: sets)
    }

    @Test func totalVolumeIgnoresWarmupSets() {
        let blocks = [block([
            line(weight: 20, reps: 15, isWarmup: true),
            line(weight: 100, reps: 5, setIndex: 1),
        ])]

        #expect(HistoryFormatting.totalVolume(blocks).actual == 500)
    }

    @Test func warmupSetsAreNotJudgedForAchievement() {
        #expect(HistoryFormatting.achieved(
            line(weight: 20, reps: 15, target: 20, targetReps: 15, isWarmup: true)
        ) == nil)
    }

    @Test func achievedSetCountCountsOnlyWorkingSets() {
        let blocks = [block([
            line(weight: 20, reps: 15, target: 20, targetReps: 15, isWarmup: true),
            line(weight: 100, reps: 5, target: 100, targetReps: 5, setIndex: 1),
        ])]

        #expect(HistoryFormatting.achievedSetCount(blocks) == (achieved: 1, total: 1))
    }

    /// 兩份平行實作要給出同一個答案——這支釘的就是「別讓它們再長歪」。
    @Test func historyAndTrainingAgreeOnVolume() {
        let blocks = [block([
            line(weight: 20, reps: 15, isWarmup: true),
            line(weight: 100, reps: 5, setIndex: 1),
            line(weight: 95, reps: 6, setIndex: 2),
        ])]

        // 100×5 + 95×6 = 1070；Training 側的同一組資料在 WarmupExclusionTests 驗
        #expect(HistoryFormatting.totalVolume(blocks).actual == 1070)
    }
}
