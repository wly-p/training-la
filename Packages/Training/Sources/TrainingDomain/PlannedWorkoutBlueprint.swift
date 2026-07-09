import Foundation
import SharedKernel

/// 「照課表訓練」的藍圖：Training 對排課資料的需求描述。
/// Training 不認識 Plan domain——由 App 把排課轉成這個值型別餵進來。
public struct PlannedWorkoutBlueprint: Equatable, Sendable {
    public let planWorkoutId: UUID
    public let name: String?
    /// 依 (exerciseIndex, setIndex) 排序的目標佇列。
    public let targets: [PlannedTargetSet]

    public init(planWorkoutId: UUID, name: String?, targets: [PlannedTargetSet]) {
        self.planWorkoutId = planWorkoutId
        self.name = name
        self.targets = targets
    }
}

public struct PlannedTargetSet: Identifiable, Equatable, Sendable {
    /// 對應 plan_set 的 id（記錄時寫進 `WorkoutSet.fromPlanSetId`）。
    public let id: UUID
    public let exerciseId: UUID
    public let exerciseIndex: Int
    public let setIndex: Int
    public let targetWeight: Weight?
    public let targetReps: Int?

    public init(
        id: UUID,
        exerciseId: UUID,
        exerciseIndex: Int,
        setIndex: Int,
        targetWeight: Weight?,
        targetReps: Int?
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.targetWeight = targetWeight
        self.targetReps = targetReps
    }
}

/// port：今天的排課（給訓練首頁的排課卡）＋ 依 id 找回藍圖（恢復進行中場次用）。
public protocol PlannedWorkoutProvider: Sendable {
    func todaysPlan() async throws -> PlannedWorkoutBlueprint?
    func blueprint(planWorkoutId: UUID) async throws -> PlannedWorkoutBlueprint?
}

/// port：訓練結束時回報排課進度（App 接到 Plan domain 的標記完成）。
public protocol PlanProgressRecorder: Sendable {
    func markDone(planWorkoutId: UUID) async throws
}
