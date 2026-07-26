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
    let listTemplates: ListTemplates
    let instantiateTemplate: InstantiateTemplate
    let listRotations: ListRotations
    let startRotationUseCase: StartRotation
    let today: @Sendable () -> DayDate
    let listExercises: ListExercises

    func todaysPlan() async throws -> PlannedWorkoutBlueprint? {
        guard let plan = try await todaysWorkout() else { return nil }
        return try await blueprint(from: plan)
    }

    func blueprint(planWorkoutId: UUID) async throws -> PlannedWorkoutBlueprint? {
        guard let plan = try await getPlanWorkout(planWorkoutId) else { return nil }
        return try await blueprint(from: plan)
    }

    func templates() async throws -> [PlannedTemplateSummary] {
        try await listTemplates().map { PlannedTemplateSummary(id: $0.id, name: $0.name) }
    }

    func instantiate(templateId: UUID) async throws -> PlannedWorkoutBlueprint? {
        let plan = try await instantiateTemplate(templateId: templateId, date: today())
        return try await blueprint(from: plan)
    }

    func activeRotations() async throws -> [PlannedRotationSummary] {
        try await listRotations()
            .filter(\.isActive)
            .compactMap { rotation in
                guard let current = rotation.current else { return nil }
                return PlannedRotationSummary(id: rotation.id, rotationName: rotation.name, currentName: current.name)
            }
    }

    func startRotation(id: UUID) async throws -> PlannedWorkoutBlueprint? {
        guard let plan = try await startRotationUseCase(id: id, date: today()) else { return nil }
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
                // 材料化後的 PlanWorkout.sets 一律 .absolute（投影用例保證），這裡解成確定公斤。
                targetWeight: set.targetWeight?.resolvedWeight,
                targetReps: set.targetReps,
                restSec: set.restSec
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

/// Plan 的「上次實際練的重量」port ← Training 的 WorkoutRepository.lastPerformance。
/// 讓「相對上次」表達式在投影收斂時查得到真實訓練紀錄（不是 Plan 自己的目標值）。
struct LastPerformedWeightLookupAdapter: LastPerformedWeightLookup {
    let workoutRepository: any WorkoutRepository

    func lastPerformedWeight(exerciseId: UUID) async throws -> Weight? {
        let sets = try await workoutRepository.lastPerformance(exerciseId: exerciseId, excludingWorkout: nil)
        return sets.map(\.weight).max { $0.value < $1.value }
    }
}

/// Plan 的動作庫 port ← Spec 的 ListExercises。
struct PlanCatalogAdapter: PlanExerciseCatalog {
    let listExercises: ListExercises

    func exercises() async throws -> [PlanCatalogExercise] {
        try await listExercises(muscleGroup: nil).map {
            PlanCatalogExercise(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup, equipment: $0.equipment)
        }
    }
}

/// Spec 的「動作有沒有被引用」port ← Training 紀錄 ＋ Plan 排課（任一引用即算被用）。
/// 這是本地落實 in_use 的地方；未來走 API 時改由伺服器 409 落實，本 adapter 不再被 wire。
struct ExerciseUsageChecker: ExerciseUsageChecking {
    let workoutRepository: any WorkoutRepository
    let planRepository: any PlanWorkoutRepository
    let templateRepository: any WorkoutTemplateRepository
    let rotationRepository: any RotationRepository
    let programRepository: any ProgramRepository

    func isUsed(exerciseId: UUID) async throws -> Bool {
        if try await workoutRepository.usesExercise(exerciseId) { return true }
        if try await planRepository.usesExercise(exerciseId) { return true }
        if try await templateRepository.usesExercise(exerciseId) { return true }
        if try await rotationRepository.usesExercise(exerciseId) { return true }
        return try await programRepository.usesExercise(exerciseId)
    }
}

/// Spec 的「被使用於」名稱清單 port ← Plan 的範本／循環／長期（編輯頁 9a 護欄）。
/// 只看 spec 層（範本/循環/長期）—— 訓練紀錄是過去的事、不是「還在用」，不列入護欄。
struct ExerciseUsageLister: ExerciseUsageListing {
    let templateRepository: any WorkoutTemplateRepository
    let rotationRepository: any RotationRepository
    let programRepository: any ProgramRepository

    func usages(exerciseId: UUID) async throws -> [ExerciseUsageRef] {
        var refs: [ExerciseUsageRef] = []
        for t in try await templateRepository.all() where t.sets.contains(where: { $0.exerciseId == exerciseId }) {
            refs.append(ExerciseUsageRef(id: t.id, name: t.name, kind: .template))
        }
        for r in try await rotationRepository.all()
        where r.workouts.contains(where: { $0.sets.contains(where: { $0.exerciseId == exerciseId }) }) {
            refs.append(ExerciseUsageRef(id: r.id, name: r.name, kind: .rotation))
        }
        for p in try await programRepository.all()
        where p.days.values.contains(where: { $0.sets.contains(where: { $0.exerciseId == exerciseId }) }) {
            refs.append(ExerciseUsageRef(id: p.id, name: p.name, kind: .program))
        }
        return refs
    }
}
