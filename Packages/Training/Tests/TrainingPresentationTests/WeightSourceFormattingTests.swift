import SharedKernel
import Testing
import TrainingDomain

@testable import TrainingPresentation

struct WeightSourceFormattingTests {
    @Test func absoluteWithBaselineIntensityHasNoAlgebraLine() {
        let source = TargetWeightSource(kind: .absolute, base: Weight(value: 60, unit: .kg), intensityFactor: 1.0)
        #expect(WeightSourceFormatting.algebraText(source) == nil)
    }

    @Test func absoluteWithIntensityShowsBaseTimesFactor() {
        let source = TargetWeightSource(kind: .absolute, base: Weight(value: 120, unit: .kg), intensityFactor: 0.75)
        #expect(WeightSourceFormatting.algebraText(source) == "120kg × 75%")
    }

    @Test func percentOf1RMResolvedShowsPercentTimesFactorAndAbility() {
        let source = TargetWeightSource(
            kind: .percentOfMax, percent: 80, abilityValue: Weight(value: 140, unit: .kg), intensityFactor: 0.75
        )
        #expect(WeightSourceFormatting.algebraText(source) == "80% · × 75% · 最大重量 140kg")
    }

    @Test func percentOf1RMAtBaselineOmitsFactorSuffix() {
        let source = TargetWeightSource(
            kind: .percentOfMax, percent: 80, abilityValue: Weight(value: 140, unit: .kg), intensityFactor: 1.0
        )
        #expect(WeightSourceFormatting.algebraText(source) == "80% · 最大重量 140kg")
    }

    @Test func percentOf1RMUnresolvedHasNoAlgebraButHasReason() {
        let source = TargetWeightSource(kind: .percentOfMax, percent: 80, abilityValue: nil, intensityFactor: 1.0)
        #expect(WeightSourceFormatting.algebraText(source) == nil)
        #expect(WeightSourceFormatting.unresolvedReason(source) != nil)
    }

    @Test func relativeToLastResolvedShowsLastPlusDelta() {
        let source = TargetWeightSource(
            kind: .relativeToLast, delta: Weight(value: 2.5, unit: .kg), lastWeight: Weight(value: 45, unit: .kg),
            intensityFactor: 0.75
        )
        #expect(WeightSourceFormatting.algebraText(source) == "上次 45kg +2.5kg · × 75%")
    }

    @Test func relativeToLastUnresolvedHasNoAlgebraButHasReason() {
        let source = TargetWeightSource(kind: .relativeToLast, delta: Weight(value: 2.5, unit: .kg), lastWeight: nil, intensityFactor: 1.0)
        #expect(WeightSourceFormatting.algebraText(source) == nil)
        #expect(WeightSourceFormatting.unresolvedReason(source) != nil)
    }

    @Test func noExpressionHasNoAlgebraButHasReason() {
        let source = TargetWeightSource(kind: .none, intensityFactor: 1.0)
        #expect(WeightSourceFormatting.algebraText(source) == nil)
        #expect(WeightSourceFormatting.unresolvedReason(source) != nil)
    }

    @Test func nilSourceHasNoAlgebraAndNoReason() {
        #expect(WeightSourceFormatting.algebraText(nil) == nil)
        #expect(WeightSourceFormatting.unresolvedReason(nil) == nil)
    }

    @Test func intensityPillOmittedAtBaseline() {
        #expect(WeightSourceFormatting.intensityPillText(1.0) == nil)
        #expect(WeightSourceFormatting.intensityPillText(0.75) == "×75%")
    }
}
