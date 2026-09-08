import Foundation
import SharedKernel
import Testing
import TrainingDomain

@testable import TrainingPresentation

private actor MockWorkoutRepo: WorkoutRepository {
    var stored: [UUID: Workout] = [:]
    func save(_ workout: Workout) async throws { stored[workout.id] = workout }
    func get(id: UUID) async throws -> Workout? { stored[id] }
    func delete(id: UUID) async throws { stored[id] = nil }
    func activeWorkout() async throws -> Workout? { nil }
    func lastPerformance(exerciseId: UUID, excludingWorkout: UUID?) async throws -> [WorkoutSet] { [] }
    func finishedWorkouts(limit: Int?) async throws -> [Workout] { [] }
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
    func templates() async throws -> [PlannedTemplateSummary] { [] }
    func instantiate(templateId: UUID) async throws -> PlannedWorkoutBlueprint? { blueprint }
    func activeRotations() async throws -> [PlannedRotationSummary] { [] }
    func previewRotation(id: UUID) async throws -> PlannedWorkoutBlueprint? { blueprint }
    func startRotation(id: UUID) async throws -> PlannedWorkoutBlueprint? { blueprint }
    func activeRestDay() async throws -> RestDayInfo? { nil }
    func moveNextWorkoutToToday() async throws {}
}

@MainActor
struct ActiveWorkoutSetTableTests {
    private let exerciseId = UUID()
    private let planWorkoutId = UUID()

    private func makeViewModel(plannedSets: Int, targetWeight: Weight = Weight(value: 60, unit: .kg)) -> ActiveWorkoutViewModel {
        let repo = MockWorkoutRepo()
        let targets = (0..<plannedSets).map { i in
            PlannedTargetSet(
                id: UUID(), exerciseId: exerciseId, exerciseName: "臥推",
                exerciseIndex: 0, setIndex: i,
                targetWeight: targetWeight, targetReps: 8, restSec: nil
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
            exerciseCatalog: MockCatalog(items: [CatalogExercise(id: exerciseId, name: "臥推", muscleGroup: .chest, equipment: .barbell)]),
            plannedProvider: MockPlanProvider(blueprint: blueprint)
        )
    }

    @Test func setTableShowsDoneCurrentAndUpcomingRows() async {
        let vm = makeViewModel(plannedSets: 4)
        await vm.onAppear()

        await vm.completeCurrentSet()   // 第 1 組完成
        await vm.completeCurrentSet()   // 第 2 組完成

        let rows = vm.setTableRows
        #expect(rows.map(\.status) == [.done, .done, .current, .upcoming])
        #expect(rows.map(\.setIndex) == [0, 1, 2, 3])
        #expect(rows[0].actual != nil)
        #expect(rows[2].actual == nil)
        #expect(rows[2].target?.targetReps == 8)
    }

    @Test func setTableStopsAtPlannedCountWithNoUpcomingPastIt() async {
        let vm = makeViewModel(plannedSets: 1)
        await vm.onAppear()

        let rows = vm.setTableRows

        #expect(rows.map(\.status) == [.current])
    }

    @Test func freeTrainingHasNoUpcomingRowsSinceThereIsNoPlannedCount() async {
        let repo = MockWorkoutRepo()
        let workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 10), startedAt: Date())
        let vm = ActiveWorkoutViewModel(
            workout: workout,
            saveProgress: SaveWorkoutProgress(repository: repo),
            finishWorkout: FinishWorkout(repository: repo),
            discardWorkout: DiscardWorkout(repository: repo),
            lastPerformance: LastPerformance(repository: repo),
            exerciseCatalog: MockCatalog(items: [CatalogExercise(id: exerciseId, name: "臥推", muscleGroup: .chest, equipment: .barbell)])
        )
        await vm.onAppear()
        await vm.select(exerciseId: exerciseId)
        await vm.completeCurrentSet()

        let rows = vm.setTableRows

        #expect(rows.map(\.status) == [.done, .current])
    }

    @Test func resetToTargetRestoresTargetValues() async {
        let vm = makeViewModel(plannedSets: 2)
        await vm.onAppear()
        #expect(vm.draftWeightValue == 60)
        vm.bumpWeight(1)
        #expect(vm.draftWeightValue == 62.5)
        #expect(vm.isDraftModifiedFromTarget == true)

        vm.resetToTarget()

        #expect(vm.draftWeightValue == 60)
        #expect(vm.isDraftModifiedFromTarget == false)
    }

    @Test func applyLastSetValuesCopiesPreviousSet() async {
        let vm = makeViewModel(plannedSets: 3)
        await vm.onAppear()
        await vm.completeCurrentSet()   // 第 1 組：60kg × 8（目標值）
        vm.bumpWeight(1)                // 第 2 組草稿改成 62.5（偏離目標）
        #expect(vm.draftWeightValue == 62.5)

        vm.applyLastSetValues()

        #expect(vm.draftWeightValue == 60)   // 回到上一組（第 1 組）記錄的值
        #expect(vm.draftReps == 8)
    }

    @Test func isDraftModifiedFromTargetFalseWhenNoTarget() async {
        let repo = MockWorkoutRepo()
        let workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 10), startedAt: Date())
        let vm = ActiveWorkoutViewModel(
            workout: workout,
            saveProgress: SaveWorkoutProgress(repository: repo),
            finishWorkout: FinishWorkout(repository: repo),
            discardWorkout: DiscardWorkout(repository: repo),
            lastPerformance: LastPerformance(repository: repo),
            exerciseCatalog: MockCatalog(items: [CatalogExercise(id: exerciseId, name: "臥推", muscleGroup: .chest, equipment: .barbell)])
        )
        await vm.onAppear()
        await vm.select(exerciseId: exerciseId)

        #expect(vm.isDraftModifiedFromTarget == false)
    }
}

/// 記錄畫面的預填要跟著偏好單位走。
///
/// 這是「切成 lb 幾乎是無效操作」的一半病因：`apply(weight:reps:)` 原本直接把來源的單位
/// 抄進草稿（`draftWeightUnit = weight.unit`），所以不管使用者選什麼，預填都跳出
/// 課表／上次紀錄當初的單位；而完全沒有線索時的退路更是寫死 `Weight(value: 20, unit: .kg)`。
@MainActor
struct PrefillFollowsPreferredUnitTests {
    private let exerciseId = UUID()

    private func makeViewModel(unit: WeightUnit, seeded: [WorkoutSet] = []) -> ActiveWorkoutViewModel {
        let repo = MockWorkoutRepo()
        let workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 8, day: 27),
                              startedAt: Date(), sets: seeded)
        return ActiveWorkoutViewModel(
            workout: workout,
            saveProgress: SaveWorkoutProgress(repository: repo),
            finishWorkout: FinishWorkout(repository: repo),
            discardWorkout: DiscardWorkout(repository: repo),
            lastPerformance: LastPerformance(repository: repo),
            exerciseCatalog: MockCatalog(items: [
                CatalogExercise(id: exerciseId, name: "臥推", muscleGroup: .chest, equipment: .barbell)
            ]),
            weightUnitStore: InMemoryWeightUnitStore(initial: unit)
        )
    }

    /// 沒有任何線索時的退路：lb 使用者不該在空白紀錄上看到 20 kg。
    @Test func fallbackUsesThePreferredUnitInsteadOfHardcodedKilograms() async {
        let vm = makeViewModel(unit: .lb)
        await vm.onAppear()
        await vm.select(exerciseId: exerciseId)

        #expect(vm.draftWeightUnit == .lb)
    }

    @Test func fallbackStillGivesKilogramsWhenThatIsThePreference() async {
        let vm = makeViewModel(unit: .kg)
        await vm.onAppear()
        await vm.select(exerciseId: exerciseId)

        #expect(vm.draftWeightUnit == .kg)
        #expect(vm.draftWeightValue == 20)
    }

    /// 沿用本場上一組時也要換算：上一組存的是 kg，偏好是 lb，草稿要變成 lb 的等值。
    @Test func reusingAPreviousSetConvertsIntoThePreferredUnit() async {
        let previous = WorkoutSet(
            id: UUID(), exerciseId: exerciseId, exerciseIndex: 0, setIndex: 0,
            measurement: .weightReps(weight: Weight(value: 100, unit: .kg), reps: 5)
        )
        let vm = makeViewModel(unit: .lb, seeded: [previous])
        await vm.onAppear()
        await vm.select(exerciseId: exerciseId)

        #expect(vm.draftWeightUnit == .lb)
        // 100 kg ≈ 220.46 lb——重點是換算過了，不是照抄 100
        #expect(vm.draftWeightValue > 200)
    }
}
