import Foundation
import PlanDomain
import SharedKernel
import Testing

@testable import PlanPresentation

/// 範本摺疊列（設計稿 19a）主行規格與細節行重量的格式。
///
/// 註：`swift test`（SwiftPM CLI）不編譯 String Catalog，`localizedString` 會回 key 本身，
/// 所以本地化那幾條只驗「選到哪一個 key」與代入的數字，實際譯文由 app 端與人眼負責。
struct TemplateBlockFormattingTests {
    private let exerciseId = UUID()

    private func sets(reps: [Int?], weights: [WeightExpression?]? = nil) -> [PlanSet] {
        reps.enumerated().map { index, rep in
            PlanSet(
                id: UUID(),
                exerciseId: exerciseId,
                exerciseIndex: 0,
                setIndex: index,
                targetWeight: weights?[index],
                targetReps: rep
            )
        }
    }

    // MARK: - 主行：組數 × 次數

    @Test func uniformRepsShowSetCountTimesReps() {
        #expect(PlanFormatting.blockSpec(sets: sets(reps: [10, 10, 10]), language: .zhHant) == "3 × 10")
    }

    /// ≤4 組直接給數值——遞減看數字就知道，而且多告訴使用者實際數字。
    @Test func upToFourVaryingSetsListEveryRepCount() {
        #expect(PlanFormatting.blockSpec(sets: sets(reps: [12, 10, 8]), language: .zhHant) == "12 · 10 · 8")
        #expect(PlanFormatting.blockSpec(sets: sets(reps: [12, 10, 10, 8]), language: .zhHant) == "12 · 10 · 10 · 8")
    }

    /// ≥5 組退回摘要，且方向要照實際資料判定——spec 範例寫死「遞增」，遞減的課表會被講錯。
    @Test func fiveOrMoreVaryingSetsFallBackToDirectionSummary() {
        let increasing = PlanFormatting.blockSpec(sets: sets(reps: [6, 7, 8, 9, 10]), language: .zhHant)
        #expect(increasing.contains("progressive"))
        #expect(increasing.contains("5"))

        let decreasing = PlanFormatting.blockSpec(sets: sets(reps: [12, 10, 8, 6, 4]), language: .zhHant)
        #expect(decreasing.contains("decreasing"))

        let mixed = PlanFormatting.blockSpec(sets: sets(reps: [8, 12, 8, 12, 8]), language: .zhHant)
        #expect(mixed.contains("mixed"))
    }

    /// 平台期那種「5 組全部一樣」不該掉進摘要分支——它是各組相同，不是各組不同。
    @Test func fiveIdenticalSetsStillUseTimesForm() {
        #expect(PlanFormatting.blockSpec(sets: sets(reps: [5, 5, 5, 5, 5]), language: .zhHant) == "5 × 5")
    }

    @Test func missingRepsCountAsZeroRatherThanCrashing() {
        #expect(PlanFormatting.blockSpec(sets: sets(reps: [nil, nil]), language: .zhHant) == "2 × 0")
    }

    @Test func emptyBlockGivesEmptyString() {
        #expect(PlanFormatting.blockSpec(sets: [], language: .zhHant).isEmpty)
    }

    // MARK: - 細節行：重量

    @Test func noWeightGivesNilSoTheDetailLineIsJustThePill() {
        #expect(PlanFormatting.blockWeight(sets: sets(reps: [10, 10]), language: .zhHant, in: .kg) == nil)
    }

    @Test func uniformAbsoluteWeightShowsItWithUnit() {
        let weight = WeightExpression.absolute(Weight(value: 60, unit: .kg))
        let text = PlanFormatting.blockWeight(sets: sets(reps: [10, 10], weights: [weight, weight]), language: .zhHant, in: .kg)
        #expect(text == "60kg")
    }

    /// 各組不同的絕對重量壓成箭頭形式，單位只印一次（19a 自己舉的例子）。
    @Test func varyingAbsoluteWeightsCollapseToArrow() {
        let text = PlanFormatting.blockWeight(
            sets: sets(reps: [10, 10, 10], weights: [
                .absolute(Weight(value: 60, unit: .kg)),
                .absolute(Weight(value: 65, unit: .kg)),
                .absolute(Weight(value: 70, unit: .kg)),
            ]),
            language: .zhHant,
            in: .kg
        )
        #expect(text == "60 → 70kg")
    }

    /// 混用百分比與公斤時不能壓縮，否則會變成看不懂的「70 → 85kg」。
    @Test func mixedExpressionKindsKeepBothFullLabels() {
        let text = PlanFormatting.blockWeight(
            sets: sets(reps: [10, 10], weights: [
                .percentOfMax(70),
                .absolute(Weight(value: 85, unit: .kg)),
            ]),
            language: .zhHant,
            in: .kg
        ) ?? ""
        #expect(text.contains("70%"))
        #expect(text.contains("85kg"))
        #expect(text.contains("→"))
    }

    @Test func percentOfMaxKeepsItsOwnLabel() {
        let text = PlanFormatting.blockWeight(
            sets: sets(reps: [10], weights: [.percentOfMax(80)]),
            language: .zhHant,
            in: .kg
        ) ?? ""
        #expect(text.contains("percentOfMax"))
        #expect(text.contains("80%"))
    }

    @Test func relativeToLastKeepsItsSign() {
        let text = PlanFormatting.blockWeight(
            sets: sets(reps: [10], weights: [.relativeToLast(delta: Weight(value: 2.5, unit: .kg))]),
            language: .zhHant,
            in: .kg
        ) ?? ""
        #expect(text.contains("+2.5kg"))
    }

    /// 部分組沒設重量時，只看有設的那些，不要印出「— → 70kg」。
    @Test func partiallySetWeightsIgnoreTheEmptyOnes() {
        let text = PlanFormatting.blockWeight(
            sets: sets(reps: [10, 10], weights: [nil, .absolute(Weight(value: 70, unit: .kg))]),
            language: .zhHant,
            in: .kg
        )
        #expect(text == "70kg")
    }
}
