import Foundation
import SharedKernel
import Testing
import TrainingDomain

struct PlannedWorkoutBlueprintTests {
    private let benchId = UUID()
    private let squatId = UUID()

    private func target(_ id: UUID, _ name: String, _ exerciseIndex: Int, _ setIndex: Int) -> PlannedTargetSet {
        PlannedTargetSet(
            id: UUID(), exerciseId: id, exerciseName: name,
            exerciseIndex: exerciseIndex, setIndex: setIndex,
            targetWeight: Weight(value: 60, unit: .kg), targetReps: 8, restSec: 60
        )
    }

    @Test func exercisesGroupsByExerciseIndexPreservingOrder() {
        let blueprint = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: "推日", targets: [
            target(benchId, "臥推", 0, 0),
            target(benchId, "臥推", 0, 1),
            target(squatId, "深蹲", 1, 0),
        ])

        let exercises = blueprint.exercises

        #expect(exercises.map(\.exerciseId) == [benchId, squatId])
        #expect(exercises.map(\.name) == ["臥推", "深蹲"])
        #expect(exercises.map(\.setCount) == [2, 1])
    }

    @Test func exercisesHandlesOutOfOrderTargets() {
        let blueprint = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: nil, targets: [
            target(squatId, "深蹲", 1, 0),
            target(benchId, "臥推", 0, 1),
            target(benchId, "臥推", 0, 0),
        ])

        #expect(blueprint.exercises.map(\.exerciseId) == [benchId, squatId])
    }

    @Test func exercisesExposeNameAndSetCount() {
        let blueprint = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: "推日", targets: [
            target(benchId, "臥推", 0, 0),
            target(benchId, "臥推", 0, 1),
            target(squatId, "深蹲", 1, 0),
        ])

        // 顯示字串（含「組/sets」）由 presentation 端 locale-aware 組出，Domain 只提供 name + setCount
        #expect(blueprint.exercises.map { "\($0.name):\($0.setCount)" } == ["臥推:2", "深蹲:1"])
    }

    @Test func targetReturnsNthSetForExercise() {
        let blueprint = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: nil, targets: [
            target(benchId, "臥推", 0, 0),
            target(benchId, "臥推", 0, 1),
        ])

        #expect(blueprint.target(exerciseId: benchId, position: 0)?.setIndex == 0)
        #expect(blueprint.target(exerciseId: benchId, position: 1)?.setIndex == 1)
        #expect(blueprint.target(exerciseId: benchId, position: 2) == nil)
    }

    @Test func targetReturnsNilForUnknownExercise() {
        let blueprint = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: nil, targets: [
            target(benchId, "臥推", 0, 0),
        ])

        #expect(blueprint.target(exerciseId: squatId, position: 0) == nil)
    }
}
