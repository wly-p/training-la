import AbilityDomain
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
    let previewRotationUseCase: PreviewRotationWorkout
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

    func previewRotation(id: UUID) async throws -> PlannedWorkoutBlueprint? {
        guard let plan = try await previewRotationUseCase(id: id) else { return nil }
        return try await blueprint(from: plan)
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
                restSec: set.restSec,
                weightSource: set.weightSource.map(Self.mapWeightSource)
            )
        }
        return PlannedWorkoutBlueprint(planWorkoutId: plan.id, name: plan.name, targets: targets)
    }

    /// Plan 的 `WeightSourceInfo` → Training 的 `TargetWeightSource`（14c）：換一層型別，
    /// 讓 Training 不用認識 Plan 的表達式型別，數值本身原封不動地搬過去。
    private static func mapWeightSource(_ info: WeightSourceInfo) -> TargetWeightSource {
        switch info.kind {
        case .none:
            return TargetWeightSource(kind: .none, intensityFactor: info.intensityFactor)
        case .absolute:
            return TargetWeightSource(kind: .absolute, base: info.base, intensityFactor: info.intensityFactor)
        case .relativeToLast:
            return TargetWeightSource(
                kind: .relativeToLast, delta: info.delta, lastWeight: info.lastWeight,
                intensityFactor: info.intensityFactor
            )
        case .percentOf1RM:
            return TargetWeightSource(
                kind: .percentOf1RM, percent: info.percent, abilityValue: info.abilityValue,
                intensityFactor: info.intensityFactor
            )
        }
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
/// `metTarget`：那組的目標次數快照 vs 實際次數——沒有快照（臨時加練）視為達標，維持舊行為。
struct LastPerformedWeightLookupAdapter: LastPerformedWeightLookup {
    let workoutRepository: any WorkoutRepository

    func lastPerformedWeight(exerciseId: UUID) async throws -> LastPerformedSet? {
        let sets = try await workoutRepository.lastPerformance(exerciseId: exerciseId, excludingWorkout: nil)
        guard let best = sets.max(by: { $0.weight.value < $1.weight.value }) else { return nil }
        let metTarget = best.targetReps.map { best.reps >= $0 } ?? true
        return LastPerformedSet(weight: best.weight, metTarget: metTarget)
    }
}

/// Plan 的「能力值(1RM)」port ← Ability 的 GetAbilityValue。讓 `%1RM` 表達式在投影收斂時
/// 查得到使用者的能力值（Plan package 不依賴 Ability，經由這個 App 層 adapter 接線）。
struct AbilityValueLookupAdapter: AbilityValueLookup {
    let getAbilityValue: GetAbilityValue

    func abilityValue(exerciseId: UUID) async throws -> Weight? {
        try await getAbilityValue(exerciseId: exerciseId)?.value
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
