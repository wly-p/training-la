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

    /// 建議值＝實際推過的最大重量，原樣回傳。刻意不套 Epley——
    /// 那會建議一個從沒推起來過的數字，還會產生 106.67 這種裝不出來的重量。
    @Test func suggestReturnsMaxWeightUnchanged() {
        let suggest = SuggestAbilityValue()
        #expect(suggest(maxWeight: Weight(value: 100, unit: .kg)) == Weight(value: 100, unit: .kg))
    }

    @Test func suggestKeepsUnit() {
        let suggest = SuggestAbilityValue()
        #expect(suggest(maxWeight: Weight(value: 225, unit: .lb)).unit == .lb)
    }
}
