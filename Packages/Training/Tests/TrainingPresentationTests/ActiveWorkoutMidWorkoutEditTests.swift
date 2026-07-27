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
    func templates() async throws -> [PlannedTemplateSummary] { [] }
    func instantiate(templateId: UUID) async throws -> PlannedWorkoutBlueprint? { blueprint }
    func activeRotations() async throws -> [PlannedRotationSummary] { [] }
    func previewRotation(id: UUID) async throws -> PlannedWorkoutBlueprint? { blueprint }
    func startRotation(id: UUID) async throws -> PlannedWorkoutBlueprint? { blueprint }
    func activeRestDay() async throws -> RestDayInfo? { nil }
}

@MainActor
struct ActiveWorkoutMidWorkoutEditTests {
    private let benchId = UUID()
    private let squatId = UUID()
    private let planWorkoutId = UUID()

    private func makeViewModel(benchSets: Int = 3, squatSets: Int = 0) -> ActiveWorkoutViewModel {
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

    @Test func addPlannedSetIncreasesPlannedCountForThatExerciseOnly() async {
        let vm = makeViewModel(benchSets: 3)
        await vm.onAppear()

        vm.addPlannedSet(for: benchId)

        let bench = vm.sessionSequence.first { $0.id == benchId }
        #expect(bench?.plannedSetCount == 4)
    }

    @Test func removePlannedSetNeverGoesBelowDoneCount() async {
        let vm = makeViewModel(benchSets: 3)
        await vm.onAppear()
        await vm.completeCurrentSet()
        await vm.completeCurrentSet()
        await vm.completeCurrentSet()   // 3 組全做完

        vm.removePlannedSet(for: benchId)   // 想少做一組，但已經做滿 3 組

        let bench = vm.sessionSequence.first { $0.id == benchId }
        #expect(bench?.plannedSetCount == 3)   // 不會降到低於已做組數
    }

    @Test func removePlannedSetReducesRemainingSets() async {
        let vm = makeViewModel(benchSets: 3)
        await vm.onAppear()
        await vm.completeCurrentSet()   // 做 1 組

        vm.removePlannedSet(for: benchId)   // 3 → 2

        let bench = vm.sessionSequence.first { $0.id == benchId }
        #expect(bench?.plannedSetCount == 2)
        #expect(bench?.doneSetCount == 1)
        await vm.completeCurrentSet()   // 補滿剩下 1 組（原本要 3 組，現在只要 2 組就滿）
        let benchAfter = vm.sessionSequence.first { $0.id == benchId }
        #expect(benchAfter?.doneSetCount == 2)
        #expect(benchAfter?.plannedSetCount == 2)
    }

    @Test func skipRemainingSetsFillsSkippedUntilPlannedCount() async {
        let vm = makeViewModel(benchSets: 3)
        await vm.onAppear()
        await vm.completeCurrentSet()   // 完成第 1 組

        await vm.skipRemainingSets(for: benchId)

        let bench = vm.sessionSequence.first { $0.id == benchId }
        #expect(bench?.doneSetCount == 3)   // 1 個完成 + 2 個 skipped，都算「已處理」
        #expect(vm.currentBlockSets.filter { $0.status == .skipped }.count == 2)
        #expect(vm.currentBlockSets.filter { $0.status == .done }.count == 1)
    }

    @Test func skipRemainingSetsOnDifferentExerciseSwitchesToItFirst() async {
        let vm = makeViewModel(benchSets: 2, squatSets: 2)
        await vm.onAppear()   // 目前在臥推

        await vm.skipRemainingSets(for: squatId)   // 動作是深蹲，不是目前正在做的臥推

        let squat = vm.sessionSequence.first { $0.id == squatId }
        #expect(squat?.doneSetCount == 2)
    }

    @Test func replaceExerciseSkipsOldAndSelectsNew() async {
        let vm = makeViewModel(benchSets: 2, squatSets: 0)
        await vm.onAppear()
        await vm.completeCurrentSet()   // 臥推完成第 1 組

        await vm.replaceExercise(benchId, with: squatId)

        // 臥推剩下的組被跳過（保留已完成的那組）
        let bench = vm.sessionSequence.first { $0.id == benchId }
        #expect(bench?.doneSetCount == 2)   // 1 done + 1 skipped
        // 換到新動作
        #expect(vm.currentExerciseId == squatId)
    }

    @Test func removeFromSessionOnlyWorksWhenNothingRecorded() async {
        let vm = makeViewModel(benchSets: 2, squatSets: 2)
        await vm.onAppear()
        await vm.completeCurrentSet()   // 臥推做 1 組 → 不能移除臥推

        vm.removeFromSession(exerciseId: benchId)
        #expect(vm.sessionSequence.contains { $0.id == benchId })   // 移除失敗，還在清單

        vm.removeFromSession(exerciseId: squatId)   // 深蹲還沒開始 → 可以移除
        #expect(vm.sessionSequence.contains { $0.id == squatId } == false)
    }

    @Test func removeFromSessionClearsCurrentExerciseWhenRemovingIt() async {
        let vm = makeViewModel(benchSets: 2, squatSets: 0)
        await vm.onAppear()   // 目前在臥推，還沒記錄任何組

        vm.removeFromSession(exerciseId: benchId)

        #expect(vm.currentExerciseId == nil)
    }
}
