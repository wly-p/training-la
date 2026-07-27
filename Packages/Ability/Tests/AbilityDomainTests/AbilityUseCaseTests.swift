import Foundation
import AbilityDomain
import SharedKernel
import Testing

actor MockAbilityValueRepository: AbilityValueRepository {
    private var stored: [UUID: AbilityValue] = [:]
    func all() async throws -> [AbilityValue] { Array(stored.values) }
    func get(exerciseId: UUID) async throws -> AbilityValue? { stored[exerciseId] }
    func save(_ value: AbilityValue) async throws { stored[value.exerciseId] = value }
    func delete(exerciseId: UUID) async throws { stored[exerciseId] = nil }
}

struct AbilityUseCaseTests {
    @Test func setAbilityValueUpsertsByExerciseId() async throws {
        let repo = MockAbilityValueRepository()
        let set = SetAbilityValue(repository: repo)
        let exerciseId = UUID()

        _ = try await set(exerciseId: exerciseId, value: Weight(value: 100, unit: .kg))
        let updated = try await set(exerciseId: exerciseId, value: Weight(value: 105, unit: .kg), source: .estimated)

        let all = try await repo.all()
        #expect(all.count == 1)
        #expect(updated.value == Weight(value: 105, unit: .kg))
        #expect(updated.source == .estimated)
    }

    @Test func getAndDeleteRoundtrip() async throws {
        let repo = MockAbilityValueRepository()
        let exerciseId = UUID()
        try await repo.save(AbilityValue(exerciseId: exerciseId, value: Weight(value: 80, unit: .kg)))

        let get = GetAbilityValue(repository: repo)
        #expect(try await get(exerciseId: exerciseId)?.value == Weight(value: 80, unit: .kg))

        let delete = DeleteAbilityValue(repository: repo)
        try await delete(exerciseId: exerciseId)
        #expect(try await get(exerciseId: exerciseId) == nil)
    }

    @Test func suggestUsesEpleyFormula() {
        let suggest = SuggestAbilityValue()
        // 80 × 8 → 80 × (1 + 8/30) ≈ 101.3（設計稿範例：「約 100」）。
        let estimated = suggest(weight: Weight(value: 80, unit: .kg), reps: 8)
        #expect(abs(estimated.value - 101.333) < 0.01)
        #expect(estimated.unit == .kg)
    }

    @Test func suggestSingleRepReturnsSameWeight() {
        let suggest = SuggestAbilityValue()
        let estimated = suggest(weight: Weight(value: 100, unit: .kg), reps: 1)
        #expect(estimated == Weight(value: 100, unit: .kg))
    }
}
