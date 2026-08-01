import Testing

@testable import SharedKernel

struct WeightTests {
    // MARK: - 顯示

    @Test func displayStringDropsTrailingZeroForWholeNumbers() {
        let weight = Weight(value: 60, unit: .kg)
        #expect(weight.displayString == "60kg")
    }

    @Test func displayStringKeepsDecimalForFractionalValues() {
        let weight = Weight(value: 62.5, unit: .kg)
        #expect(weight.displayString == "62.5kg")
    }

    @Test func displayStringUsesUnitRawValue() {
        #expect(Weight(value: 135, unit: .lb).displayString == "135lb")
    }

    /// 細級距（0.17）算出來的值會帶浮點雜訊，不能整串印在畫面上。
    @Test func formattedTrimsFloatingPointNoise() {
        #expect(Weight.formatted(99.96000000000001) == "99.96")
        #expect(Weight.formatted(33.830000000000005) == "33.83")
        #expect(Weight.formatted(65.90000000000003) == "65.9")
        #expect(Weight.formatted(0.17) == "0.17")
        #expect(Weight.formatted(60) == "60")
    }

    @Test func displayStringDoesNotConvertUnits() {
        // 顯示不替呼叫端決定要不要換算——單位照這筆自己的。
        #expect(Weight(value: 60, unit: .lb).displayString == "60lb")
    }

    // MARK: - 換算

    @Test func convertsKilogramsToPounds() {
        let converted = Weight(value: 100, unit: .kg).converted(to: .lb)
        #expect(converted.unit == .lb)
        #expect(abs(converted.value - 220.462262185) < 0.000001)
    }

    @Test func convertsPoundsToKilograms() {
        let converted = Weight(value: 220.462262185, unit: .lb).converted(to: .kg)
        #expect(converted.unit == .kg)
        #expect(abs(converted.value - 100) < 0.000001)
    }

    @Test func convertingToSameUnitReturnsSelf() {
        let weight = Weight(value: 62.5, unit: .kg)
        #expect(weight.converted(to: .kg).value == 62.5)
    }

    /// kg → lb → kg 的往返不能改變相等性（這正是假 PR 的來源）。
    @Test func roundTripConversionStaysEqual() {
        let original = Weight(value: 100, unit: .kg)
        let roundTripped = original.converted(to: .lb).converted(to: .kg)
        #expect(original == roundTripped)
    }

    @Test func kilogramsNormalisesForAggregation() {
        #expect(abs(Weight(value: 220.462262185, unit: .lb).kilograms - 100) < 0.000001)
        #expect(Weight(value: 60, unit: .kg).kilograms == 60)
    }

    // MARK: - 比較（換算後）

    @Test func equalityConvertsAcrossUnits() {
        #expect(Weight(value: 100, unit: .kg) == Weight(value: 220.462262185, unit: .lb))
    }

    @Test func differentWeightsAreNotEqualEvenWithSameNumber() {
        // 60kg（132lb）跟 60lb 不是同一個重量。
        #expect(Weight(value: 60, unit: .kg) != Weight(value: 60, unit: .lb))
        #expect(Weight(value: 60, unit: .kg) != Weight(value: 61, unit: .kg))
    }

    /// 這是整個改動的重點：100 lb 不可以被判定成勝過 100 kg。
    @Test func comparisonConvertsAcrossUnits() {
        #expect(Weight(value: 100, unit: .kg) > Weight(value: 100, unit: .lb))
        #expect(Weight(value: 200, unit: .lb) < Weight(value: 100, unit: .kg))
        #expect(Weight(value: 250, unit: .lb) > Weight(value: 100, unit: .kg))
    }

    /// Comparable 與 Equatable 必須一致：不大於、不小於，就必須相等。
    @Test func comparableAndEquatableAgree() {
        let kg = Weight(value: 100, unit: .kg)
        let lb = Weight(value: 220.462262185, unit: .lb)
        #expect(!(kg < lb))
        #expect(!(lb < kg))
        #expect(kg == lb)
    }

    @Test func equalWeightsHashTheSame() {
        let kg = Weight(value: 100, unit: .kg)
        let lb = Weight(value: 220.462262185, unit: .lb)
        #expect(kg.hashValue == lb.hashValue)
    }

    @Test func sortingUsesRealWeightNotRawValue() {
        let sorted = [
            Weight(value: 150, unit: .lb),   // 68.0 kg
            Weight(value: 60, unit: .kg),
            Weight(value: 100, unit: .lb),   // 45.4 kg
        ].sorted()
        #expect(sorted.map(\.unit) == [.lb, .kg, .lb])
        #expect(sorted.map(\.value) == [100, 60, 150])
    }

    // MARK: - 加減

    @Test func additionConvertsAndKeepsLeftUnit() {
        let sum = Weight(value: 100, unit: .kg) + Weight(value: 220.462262185, unit: .lb)
        #expect(sum.unit == .kg)
        #expect(abs(sum.value - 200) < 0.000001)
    }

    @Test func subtractionConvertsAndKeepsLeftUnit() {
        let diff = Weight(value: 220.462262185, unit: .lb) - Weight(value: 50, unit: .kg)
        #expect(diff.unit == .lb)
        #expect(abs(diff.value - 110.2311310925) < 0.000001)
    }

    // MARK: - 單位

    @Test func weightUnitHasKgAndLb() {
        #expect(WeightUnit.allCases == [.kg, .lb])
    }
}
