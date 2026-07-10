import Foundation
import SharedKernel
import Testing
import TrainingDomain

@testable import TrainingPresentation

// MARK: - Mocks

private actor MockWorkoutRepo: WorkoutRepository {
    var stored: [UUID: Workout] = [:]
    func save(_ workout: Workout) async throws { stored[workout.id] = workout }
    func get(id: UUID) async throws -> Workout? { stored[id] }
    func delete(id: UUID) async throws { stored[id] = nil }
    func activeWorkout() async throws -> Workout? { nil }
    func lastPerformance(exerciseId: UUID, excludingWorkout: UUID?) async throws -> [WorkoutSet] { [] }
    func finishedWorkouts() async throws -> [Workout] { [] }
    func exerciseHistory(exerciseId: UUID) async throws -> [ExerciseSetRecord] { [] }
}

private struct MockCatalog: ExerciseCatalog {
    let items: [CatalogExercise]
    func exercises() async throws -> [CatalogExercise] { items }
}

private struct MockPlanProvider: PlannedWorkoutProvider {
    let blueprint: PlannedWorkoutBlueprint
    func todaysPlan() async throws -> PlannedWorkoutBlueprint? { blueprint }
    func blueprint(planWorkoutId: UUID) async throws -> PlannedWorkoutBlueprint? { blueprint }
}

@MainActor
struct ActiveWorkoutRestTests {
    private let exerciseId = UUID()
    private let planWorkoutId = UUID()

    /// 建一個「該動作 N 組、每組休息 60 秒」的照課表場次 VM。
    private func makeViewModel(plannedSets: Int) -> ActiveWorkoutViewModel {
        let repo = MockWorkoutRepo()
        let targets = (0..<plannedSets).map { i in
            PlannedTargetSet(
                id: UUID(), exerciseId: exerciseId, exerciseName: "臥推",
                exerciseIndex: 0, setIndex: i,
                targetWeight: Weight(value: 60, unit: .kg), targetReps: 8, restSec: 60
            )
        }
        let blueprint = PlannedWorkoutBlueprint(planWorkoutId: planWorkoutId, name: "推日", targets: targets)
        let workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 10),
                              planWorkoutId: planWorkoutId, startedAt: Date())
        return ActiveWorkoutViewModel(
            workout: workout,
            saveProgress: SaveWorkoutProgress(repository: repo),
            finishWorkout: FinishWorkout(repository: repo),
            discardWorkout: DiscardWorkout(repository: repo),
            lastPerformance: LastPerformance(repository: repo),
            exerciseCatalog: MockCatalog(items: [CatalogExercise(id: exerciseId, name: "臥推", muscleGroup: .chest)]),
            plannedProvider: MockPlanProvider(blueprint: blueprint)
        )
    }

    @Test func restStartsBetweenSetsButNotAfterLastSet() async {
        let vm = makeViewModel(plannedSets: 3)
        await vm.onAppear() // 載入藍圖、自動選臥推

        // 第 1 組（3 組中）→ 還有下一組 → 進入休息
        await vm.completeCurrentSet()
        #expect(vm.restRemaining == 60)
        vm.dismissRest()

        // 第 2 組 → 還有下一組 → 進入休息
        await vm.completeCurrentSet()
        #expect(vm.restRemaining == 60)
        vm.dismissRest()

        // 第 3 組（最後一組）→ 不應該進入休息
        await vm.completeCurrentSet()
        #expect(vm.restRemaining == nil)
    }

    @Test func singleSetExerciseNeverRests() async {
        let vm = makeViewModel(plannedSets: 1)
        await vm.onAppear()

        await vm.completeCurrentSet()
        #expect(vm.restRemaining == nil)
    }

    @Test func manualRestCanStartRegardless() async {
        let vm = makeViewModel(plannedSets: 1)
        await vm.onAppear()

        // 手動設休息（沒設休息時間的情境也能用）
        vm.startRest(seconds: 90)
        #expect(vm.restRemaining == 90)

        vm.adjustRest(15)
        #expect(vm.restRemaining == 105)

        vm.dismissRest()
        #expect(vm.restRemaining == nil)
    }
}
