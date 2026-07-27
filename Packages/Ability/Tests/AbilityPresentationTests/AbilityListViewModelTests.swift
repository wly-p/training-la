import Foundation
import AbilityDomain
import SharedKernel
import Testing

@testable import AbilityPresentation

actor MockAbilityRepo: AbilityValueRepository {
    private var stored: [UUID: AbilityValue] = [:]
    func all() async throws -> [AbilityValue] { Array(stored.values) }
    func get(exerciseId: UUID) async throws -> AbilityValue? { stored[exerciseId] }
    func save(_ value: AbilityValue) async throws { stored[value.exerciseId] = value }
    func delete(exerciseId: UUID) async throws { stored[exerciseId] = nil }
}

struct MockPracticedLister: PracticedExerciseLister {
    let items: [PracticedExercise]
    func practicedExercises() async throws -> [PracticedExercise] { items }
}

@MainActor
private func makeViewModel(repo: MockAbilityRepo, practiced: [PracticedExercise]) -> AbilityListViewModel {
    AbilityListViewModel(
        listAbilityValues: ListAbilityValues(repository: repo),
        setAbilityValue: SetAbilityValue(repository: repo),
        practicedLister: MockPracticedLister(items: practiced)
    )
}

@MainActor
struct AbilityListViewModelTests {
    @Test func loadShowsSuggestionWhenNoCurrentValue() async throws {
        let benchId = UUID()
        let repo = MockAbilityRepo()
        let vm = makeViewModel(
            repo: repo,
            practiced: [PracticedExercise(exerciseId: benchId, exerciseName: "臥推", lastWeight: Weight(value: 80, unit: .kg), lastReps: 8)]
        )

        await vm.load()

        #expect(vm.rows.count == 1)
        #expect(vm.rows.first?.current == nil)
        #expect(vm.rows.first?.suggestion != nil)   // Epley: 80 × (1+8/30) ≈ 101.3
    }

    @Test func loadHidesSuggestionWhenItMatchesCurrentValue() async throws {
        let benchId = UUID()
        let repo = MockAbilityRepo()
        // 先手動設一個剛好等於推算值的 1RM，避免一直被提示更新同一個數字。
        let suggested = SuggestAbilityValue()(weight: Weight(value: 80, unit: .kg), reps: 8)
        try await repo.save(AbilityValue(exerciseId: benchId, value: suggested))
        let vm = makeViewModel(
            repo: repo,
            practiced: [PracticedExercise(exerciseId: benchId, exerciseName: "臥推", lastWeight: Weight(value: 80, unit: .kg), lastReps: 8)]
        )

        await vm.load()

        #expect(vm.rows.first?.suggestion == nil)
    }

    @Test func setValuePersistsAsManualAndReloads() async throws {
        let benchId = UUID()
        let repo = MockAbilityRepo()
        let vm = makeViewModel(
            repo: repo,
            practiced: [PracticedExercise(exerciseId: benchId, exerciseName: "臥推", lastWeight: Weight(value: 80, unit: .kg), lastReps: 8)]
        )
        await vm.load()

        await vm.setValue(exerciseId: benchId, value: Weight(value: 100, unit: .kg))

        #expect(vm.rows.first?.current?.value == Weight(value: 100, unit: .kg))
        #expect(vm.rows.first?.current?.source == .manual)
    }

    @Test func acceptSuggestionPersistsAsEstimated() async throws {
        let benchId = UUID()
        let repo = MockAbilityRepo()
        let vm = makeViewModel(
            repo: repo,
            practiced: [PracticedExercise(exerciseId: benchId, exerciseName: "臥推", lastWeight: Weight(value: 80, unit: .kg), lastReps: 8)]
        )
        await vm.load()
        let row = vm.rows[0]

        await vm.acceptSuggestion(row)

        #expect(vm.rows.first?.current?.source == .estimated)
        #expect(vm.rows.first?.suggestion == nil)   // 接受後跟目前值一致，不再提示
    }

    @Test func rowsSortedByExerciseName() async throws {
        let repo = MockAbilityRepo()
        let vm = makeViewModel(
            repo: repo,
            practiced: [
                PracticedExercise(exerciseId: UUID(), exerciseName: "Squat", lastWeight: Weight(value: 100, unit: .kg), lastReps: 5),
                PracticedExercise(exerciseId: UUID(), exerciseName: "Bench", lastWeight: Weight(value: 80, unit: .kg), lastReps: 8),
            ]
        )

        await vm.load()

        #expect(vm.rows.map(\.exerciseName) == ["Bench", "Squat"])
    }
}
