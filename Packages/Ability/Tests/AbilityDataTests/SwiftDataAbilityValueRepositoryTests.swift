import Foundation
import AbilityDomain
import SharedKernel
import SwiftData
import Testing

@testable import AbilityData

struct SwiftDataAbilityValueRepositoryTests {
    private func makeRepository() throws -> any AbilityValueRepository {
        let container = try ModelContainer(
            for: Schema(AbilityDataFactory.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return AbilityDataFactory.makeAbilityValueRepository(container: container)
    }

    @Test func saveThenGetRoundTrips() async throws {
        let repo = try makeRepository()
        let exerciseId = UUID()
        let ability = AbilityValue(exerciseId: exerciseId, value: Weight(value: 100, unit: .kg), source: .manual)

        try await repo.save(ability)
        let fetched = try await repo.get(exerciseId: exerciseId)

        #expect(fetched == ability)
    }

    @Test func saveUpsertsByExerciseId() async throws {
        let repo = try makeRepository()
        let exerciseId = UUID()
        try await repo.save(AbilityValue(exerciseId: exerciseId, value: Weight(value: 100, unit: .kg)))
        try await repo.save(AbilityValue(exerciseId: exerciseId, value: Weight(value: 105, unit: .kg), source: .estimated))

        let all = try await repo.all()
        #expect(all.count == 1)
        #expect(all.first?.value == Weight(value: 105, unit: .kg))
    }

    @Test func deleteRemovesRecord() async throws {
        let repo = try makeRepository()
        let exerciseId = UUID()
        try await repo.save(AbilityValue(exerciseId: exerciseId, value: Weight(value: 100, unit: .kg)))

        try await repo.delete(exerciseId: exerciseId)

        #expect(try await repo.get(exerciseId: exerciseId) == nil)
    }
}
