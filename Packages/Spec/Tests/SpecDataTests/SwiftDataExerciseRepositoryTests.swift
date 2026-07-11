import Foundation
import SharedKernel
import SpecDomain
import SwiftData
import Testing

@testable import SpecData

/// 用 in-memory ModelContainer 測真實的 SwiftData 實作，不落地、免模擬器。
struct SwiftDataExerciseRepositoryTests {
    private func makeRepository() throws -> any ExerciseRepository {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Schema(SpecDataFactory.models),
            configurations: config
        )
        return SpecDataFactory.makeExerciseRepository(container: container)
    }

    private func exercise(name: String, muscleGroup: MuscleGroup = .chest, equipment: Equipment = .barbell) -> Exercise {
        Exercise(
            id: UUID(),
            name: name,
            muscleGroup: muscleGroup,
            equipment: equipment,
            description: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    @Test func createThenListRoundTrips() async throws {
        let repo = try makeRepository()
        let benchPress = exercise(name: "臥推")

        try await repo.create(benchPress)
        let listed = try await repo.list(muscleGroup: nil)

        #expect(listed == [benchPress])
    }

    @Test func listSortsByNameAndFiltersByMuscleGroup() async throws {
        let repo = try makeRepository()
        try await repo.create(exercise(name: "深蹲", muscleGroup: .legs))
        try await repo.create(exercise(name: "臥推", muscleGroup: .chest))
        try await repo.create(exercise(name: "腿推", muscleGroup: .legs))

        let all = try await repo.list(muscleGroup: nil)
        let legs = try await repo.list(muscleGroup: .legs)

        // SortDescriptor(\.name) 對 String 預設 localizedStandard 排序，斷言要用同一種比較
        let expected = all.map(\.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        #expect(all.map(\.name) == expected)
        #expect(Set(legs.map(\.muscleGroup)) == [.legs])
        #expect(legs.count == 2)
    }

    @Test func updatePersistsChanges() async throws {
        let repo = try makeRepository()
        var target = exercise(name: "臥推")
        try await repo.create(target)

        target.name = "上斜臥推"
        target.description = "30度"
        try await repo.update(target)

        let fetched = try await repo.get(id: target.id)
        #expect(fetched?.name == "上斜臥推")
        #expect(fetched?.description == "30度")
    }

    @Test func updateMissingThrowsNotFound() async throws {
        let repo = try makeRepository()
        let ghost = exercise(name: "幽靈")

        await #expect(throws: ExerciseRepositoryError.notFound(id: ghost.id)) {
            try await repo.update(ghost)
        }
    }

    @Test func deleteRemovesRow() async throws {
        let repo = try makeRepository()
        let target = exercise(name: "臥推")
        try await repo.create(target)

        try await repo.delete(id: target.id)

        #expect(try await repo.get(id: target.id) == nil)
        #expect(try await repo.list(muscleGroup: nil).isEmpty)
    }
}
