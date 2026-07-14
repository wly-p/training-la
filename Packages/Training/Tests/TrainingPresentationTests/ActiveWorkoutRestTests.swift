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
    func usesExercise(_ exerciseId: UUID) async throws -> Bool { false }
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

    /// 跳過此組的契約：只記一組、狀態 .skipped、且不觸發休息。
    /// （bug③ 的誤觸表現就是多記了 .skipped 組，這裡固定住「正常跳過」的預期行為。）
    @Test func skipRecordsSingleSkippedSetWithoutRest() async {
        let vm = makeViewModel(plannedSets: 3)
        await vm.onAppear()

        await vm.skipCurrentSet()

        #expect(vm.currentBlockSets.count == 1)
        #expect(vm.currentBlockSets.last?.status == .skipped)
        #expect(vm.restRemaining == nil)
    }
}

@MainActor
struct ActiveWorkoutCompletionTests {
    private let benchId = UUID()
    private let squatId = UUID()
    private let planWorkoutId = UUID()

    /// 臥推 benchSets 組 + 深蹲 squatSets 組的照課表場次。
    private func makeViewModel(benchSets: Int, squatSets: Int) -> ActiveWorkoutViewModel {
        let repo = MockWorkoutRepo()
        func targets(_ id: UUID, _ name: String, _ index: Int, _ count: Int) -> [PlannedTargetSet] {
            (0..<count).map { i in
                PlannedTargetSet(id: UUID(), exerciseId: id, exerciseName: name,
                                 exerciseIndex: index, setIndex: i,
                                 targetWeight: Weight(value: 60, unit: .kg), targetReps: 8, restSec: nil)
            }
        }
        let blueprint = PlannedWorkoutBlueprint(
            planWorkoutId: planWorkoutId, name: "推日",
            targets: targets(benchId, "臥推", 0, benchSets) + targets(squatId, "深蹲", 1, squatSets)
        )
        let workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 10),
                              planWorkoutId: planWorkoutId, startedAt: Date())
        return ActiveWorkoutViewModel(
            workout: workout,
            saveProgress: SaveWorkoutProgress(repository: repo),
            finishWorkout: FinishWorkout(repository: repo),
            discardWorkout: DiscardWorkout(repository: repo),
            lastPerformance: LastPerformance(repository: repo),
            exerciseCatalog: MockCatalog(items: [
                CatalogExercise(id: benchId, name: "臥推", muscleGroup: .chest),
                CatalogExercise(id: squatId, name: "深蹲", muscleGroup: .legs),
            ]),
            plannedProvider: MockPlanProvider(blueprint: blueprint)
        )
    }

    private func complete(_ vm: ActiveWorkoutViewModel, times: Int) async {
        for _ in 0..<times {
            await vm.completeCurrentSet()
            vm.dismissRest()
        }
    }

    @Test func cardShowsOnlyAfterLastPlannedSet() async {
        let vm = makeViewModel(benchSets: 3, squatSets: 3)
        await vm.onAppear() // 自動選臥推

        await complete(vm, times: 2)
        #expect(vm.showExerciseComplete == false) // 還沒做滿 3 組

        await complete(vm, times: 1)
        #expect(vm.showExerciseComplete == true)  // 第 3 組 → 跳卡片
        #expect(vm.completedExerciseName == "臥推")
        #expect(vm.isPlanFullyDone == false)       // 還有深蹲
        #expect(vm.nextPlannedName == "深蹲")
    }

    @Test func continueSameExerciseDoesNotRetrigger() async {
        let vm = makeViewModel(benchSets: 3, squatSets: 3)
        await vm.onAppear()
        await complete(vm, times: 3)
        #expect(vm.showExerciseComplete == true)

        vm.continueSameExercise()       // 選「再做一組」
        #expect(vm.showExerciseComplete == false)

        await complete(vm, times: 1)    // 加練第 4 組
        #expect(vm.showExerciseComplete == false) // 不再重複跳
    }

    @Test func lastExerciseMarksPlanFullyDone() async {
        let vm = makeViewModel(benchSets: 1, squatSets: 1)
        await vm.onAppear()

        await complete(vm, times: 1)    // 臥推做完
        #expect(vm.isPlanFullyDone == false)
        vm.dismissExerciseComplete()

        await vm.advanceToNextPlanned() // 到深蹲
        await complete(vm, times: 1)    // 深蹲做完（課表最後一個）
        #expect(vm.showExerciseComplete == true)
        #expect(vm.isPlanFullyDone == true)
    }
}
