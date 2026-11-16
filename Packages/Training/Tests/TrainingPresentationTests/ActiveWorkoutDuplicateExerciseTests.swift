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

/// 同一份課表裡同一個動作出現兩次（例：臥推 3 組 → 深蹲 → 再回來臥推 2 組）。
///
/// 範本／排課編輯器的動作選擇器不排除已經加過的動作，所以這是使用者真的做得出來的課表。
/// 訓練畫面整套狀態是以 exerciseId 為 key 的；原本 `plannedSetCounts` 用
/// `Dictionary(uniqueKeysWithValues:)` 建表，遇到重複的 exerciseId 會直接 trap——
/// 一開始訓練就閃退，而且那份課表之後每次點開都閃退。
@MainActor
struct ActiveWorkoutDuplicateExerciseTests {
    private let benchId = UUID()
    private let squatId = UUID()
    private let planWorkoutId = UUID()

    /// 臥推 3 組（區塊 0）→ 深蹲 2 組（區塊 1）→ 臥推 2 組（區塊 2）。
    private func makeViewModel() -> ActiveWorkoutViewModel {
        let repo = MockWorkoutRepo()
        func targets(_ id: UUID, _ name: String, _ index: Int, _ count: Int, _ kg: Double) -> [PlannedTargetSet] {
            (0..<count).map { i in
                PlannedTargetSet(id: UUID(), exerciseId: id, exerciseName: name,
                                 exerciseIndex: index, setIndex: i,
                                 targetWeight: Weight(value: kg, unit: .kg), targetReps: 8, restSec: nil)
            }
        }
        let blueprint = PlannedWorkoutBlueprint(
            planWorkoutId: planWorkoutId, name: "推日",
            targets: targets(benchId, "臥推", 0, 3, 60)
                + targets(squatId, "深蹲", 1, 2, 100)
                + targets(benchId, "臥推", 2, 2, 50)
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
                CatalogExercise(id: benchId, name: "臥推", muscleGroup: .chest, equipment: .barbell),
                CatalogExercise(id: squatId, name: "深蹲", muscleGroup: .legs, equipment: .barbell),
            ]),
            plannedProvider: MockPlanProvider(blueprint: blueprint)
        )
    }

    @Test func sessionSequenceMergesRepeatedExerciseIntoOneRow() async {
        let vm = makeViewModel()
        await vm.onAppear()

        // 一個動作一列（列的 id 是 exerciseId，重複的話 SwiftUI 的 ForEach 也會出事），
        // 組數是兩個區塊加總。
        let sequence = vm.sessionSequence
        #expect(sequence.map(\.id) == [benchId, squatId])
        #expect(sequence.first { $0.id == benchId }?.plannedSetCount == 5)
        #expect(sequence.first { $0.id == squatId }?.plannedSetCount == 2)
    }

    @Test func repeatedExerciseIsOnlyDoneAfterAllItsSets() async {
        let vm = makeViewModel()
        await vm.onAppear()
        #expect(vm.currentExerciseId == benchId)

        // 做完前 3 組（第一個區塊）還不算做滿——後面還有 2 組。
        for _ in 0..<3 { await vm.completeCurrentSet() }
        #expect(vm.showExerciseComplete == false)
        // 第 4 組的目標來自第二個臥推區塊（50kg），不是空的。
        #expect(vm.currentTarget?.targetWeight == Weight(value: 50, unit: .kg))

        for _ in 0..<2 { await vm.completeCurrentSet() }
        #expect(vm.showExerciseComplete)
        #expect(vm.nextPlannedExerciseId == squatId)
    }
}
