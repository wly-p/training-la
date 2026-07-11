import Testing

@testable import SharedKernel

struct WeightTests {
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

    @Test func doesNotConvertBetweenUnits() {
        let kg = Weight(value: 60, unit: .kg)
        let lb = Weight(value: 60, unit: .lb)
        #expect(kg != lb)
    }

    @Test func equatableComparesValueAndUnit() {
        #expect(Weight(value: 60, unit: .kg) == Weight(value: 60, unit: .kg))
        #expect(Weight(value: 60, unit: .kg) != Weight(value: 61, unit: .kg))
    }

    @Test func weightUnitHasKgAndLb() {
        #expect(WeightUnit.allCases == [.kg, .lb])
    }
}
