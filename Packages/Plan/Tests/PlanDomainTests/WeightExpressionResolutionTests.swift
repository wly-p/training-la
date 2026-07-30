import Foundation
import SharedKernel
import Testing

@testable import PlanDomain

private let exerciseId = UUID()

struct ResolveWeightExpressionTests {
    @Test func percentOf1RMResolvesUsingAbilityValue() async throws {
        // 80% of a 100kg 1RM, barbell step 2.5 → 80kg exactly.
        let (resolved, _) = try await resolveWeightExpression(
            .percentOf1RM(80), weightStep: 2.5, intensityFactor: 1.0, exerciseId: exerciseId,
            lastPerformedLookup: MockLastPerformedWeightLookup(),
            abilityValueLookup: MockAbilityValueLookup(Weight(value: 100, unit: .kg))
        )
        #expect(resolved == .absolute(Weight(value: 80, unit: .kg)))
    }

    @Test func percentOf1RMWithoutAbilityValueResolvesToNil() async throws {
        let (resolved, _) = try await resolveWeightExpression(
            .percentOf1RM(80), weightStep: 2.5, intensityFactor: 1.0, exerciseId: exerciseId,
            lastPerformedLookup: MockLastPerformedWeightLookup(),
            abilityValueLookup: MockAbilityValueLookup(nil)
        )
        #expect(resolved == nil)
    }

    @Test func intensityFactorAppliesAfterBaseAndBeforeRounding() async throws {
        // 100kg base × 0.75 = 75kg，barbell 2.5 已對齊，不用取整。
        let (resolved, _) = try await resolveWeightExpression(
            .absolute(Weight(value: 100, unit: .kg)), weightStep: 2.5, intensityFactor: 0.75, exerciseId: exerciseId,
            lastPerformedLookup: MockLastPerformedWeightLookup(),
            abilityValueLookup: MockAbilityValueLookup()
        )
        #expect(resolved == .absolute(Weight(value: 75, unit: .kg)))
    }

    @Test func intensityFactorRoundsDownToWeightStep() async throws {
        // 85kg × 0.75 = 63.75 → 器材遞增 2.5 向下取整 = 62.5（一律向下取整，寧輕不重）。
        let (resolved, _) = try await resolveWeightExpression(
            .absolute(Weight(value: 85, unit: .kg)), weightStep: 2.5, intensityFactor: 0.75, exerciseId: exerciseId,
            lastPerformedLookup: MockLastPerformedWeightLookup(),
            abilityValueLookup: MockAbilityValueLookup()
        )
        #expect(resolved == .absolute(Weight(value: 62.5, unit: .kg)))
    }

    @Test func relativeToLastAddsDeltaWhenLastSetMetTarget() async throws {
        let (resolved, _) = try await resolveWeightExpression(
            .relativeToLast(delta: Weight(value: 2.5, unit: .kg)), weightStep: 2.5, intensityFactor: 1.0,
            exerciseId: exerciseId,
            lastPerformedLookup: MockLastPerformedWeightLookup(Weight(value: 60, unit: .kg), metTarget: true),
            abilityValueLookup: MockAbilityValueLookup()
        )
        #expect(resolved == .absolute(Weight(value: 62.5, unit: .kg)))
    }

    @Test func relativeToLastKeepsSameWeightWhenLastSetDidNotMeetTarget() async throws {
        // 上次沒達標（做了 8 下、目標 10 下）→ 這次維持上次的重量，不 +delta。
        let (resolved, _) = try await resolveWeightExpression(
            .relativeToLast(delta: Weight(value: 2.5, unit: .kg)), weightStep: 2.5, intensityFactor: 1.0,
            exerciseId: exerciseId,
            lastPerformedLookup: MockLastPerformedWeightLookup(Weight(value: 60, unit: .kg), metTarget: false),
            abilityValueLookup: MockAbilityValueLookup()
        )
        #expect(resolved == .absolute(Weight(value: 60, unit: .kg)))
    }

    @Test func nilExpressionStaysNil() async throws {
        let (resolved, _) = try await resolveWeightExpression(
            nil, weightStep: 2.5, intensityFactor: 1.0, exerciseId: exerciseId,
            lastPerformedLookup: MockLastPerformedWeightLookup(), abilityValueLookup: MockAbilityValueLookup()
        )
        #expect(resolved == nil)
    }
}
