import Foundation
import PlanDomain
import SharedKernel
import SpecDomain
import TrainingDomain

/// Plan ↔ Training ↔ Spec 三個 domain 的接線，全部集中在 Composition Root。
/// 每個 adapter 只在這裡認識多個 domain；domain 之間仍互不 import。

/// Training 的「今天有什麼排課」port ← Plan 的 TodaysWorkout（＋ Spec 動作名稱）。
struct PlanProviderAdapter: PlannedWorkoutProvider {
    let todaysWorkout: TodaysWorkout
    let getPlanWorkout: @Sendable (UUID) async throws -> PlanWorkout?
    let listExercises: ListExercises

    func todaysPlan() async throws -> PlannedWorkoutBlueprint? {
        guard let plan = try await todaysWorkout() else { return nil }
        return try await blueprint(from: plan)
    }

    func blueprint(planWorkoutId: UUID) async throws -> PlannedWorkoutBlueprint? {
        guard let plan = try await getPlanWorkout(planWorkoutId) else { return nil }
        return try await blueprint(from: plan)
    }

    private func blueprint(from plan: PlanWorkout) async throws -> PlannedWorkoutBlueprint {
        let names = Dictionary(uniqueKeysWithValues:
            try await listExercises(muscleGroup: nil).map { ($0.id, $0.name) })
        let targets = plan.sets.map { set in
            PlannedTargetSet(
                id: set.id,
                exerciseId: set.exerciseId,
                exerciseName: names[set.exerciseId] ?? "動作",
                exerciseIndex: set.exerciseIndex,
                setIndex: set.setIndex,
                targetWeight: set.targetWeight,
                targetReps: set.targetReps
            )
        }
        return PlannedWorkoutBlueprint(planWorkoutId: plan.id, name: plan.name, targets: targets)
    }
}

/// Training 的「標記排課完成」port ← Plan 的 MarkPlanWorkoutDone。
struct PlanProgressAdapter: PlanProgressRecorder {
    let markDone: MarkPlanWorkoutDone

    func markDone(planWorkoutId: UUID) async throws {
        try await markDone(id: planWorkoutId)
    }
}

/// Plan 的動作庫 port ← Spec 的 ListExercises。
struct PlanCatalogAdapter: PlanExerciseCatalog {
    let listExercises: ListExercises

    func exercises() async throws -> [PlanCatalogExercise] {
        try await listExercises(muscleGroup: nil).map {
            PlanCatalogExercise(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup)
        }
    }
}
