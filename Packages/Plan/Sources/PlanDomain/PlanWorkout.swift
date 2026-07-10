import Foundation
import SharedKernel

/// 一次排課（個人層 plan_workout）。v0 App 只做單獨排課（不掛在菜單 plan 底下）。
/// aggregate root：連同 sets 整包寫入/取代，對齊 API。
public struct PlanWorkout: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String?
    /// nil＝循環（依 orderIndex 輪替）；有值＝指定某天做。
    public var date: DayDate?
    public var status: PlanWorkoutStatus
    /// 循環模式下的輪替順序。
    public var orderIndex: Int
    /// 依 (exerciseIndex, setIndex) 排序的目標。
    public var sets: [PlanSet]

    public init(
        id: UUID,
        name: String?,
        date: DayDate?,
        status: PlanWorkoutStatus = .notStarted,
        orderIndex: Int,
        sets: [PlanSet] = []
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.status = status
        self.orderIndex = orderIndex
        self.sets = sets
    }

    public var isCycle: Bool { date == nil }

    /// 依 exerciseIndex 分組、組內依 setIndex 排序。
    public var blocks: [PlanBlock] {
        Dictionary(grouping: sets, by: \.exerciseIndex)
            .sorted { $0.key < $1.key }
            .map { index, sets in
                PlanBlock(
                    exerciseIndex: index,
                    exerciseId: sets[0].exerciseId,
                    sets: sets.sorted { $0.setIndex < $1.setIndex }
                )
            }
    }
}

/// 一組目標（plan_set）。
public struct PlanSet: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var exerciseId: UUID
    public var exerciseIndex: Int
    public var setIndex: Int
    public var targetWeight: Weight?
    public var targetReps: Int?
    public var restSec: Int?

    public init(
        id: UUID,
        exerciseId: UUID,
        exerciseIndex: Int,
        setIndex: Int,
        targetWeight: Weight?,
        targetReps: Int?,
        restSec: Int? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.restSec = restSec
    }
}

public struct PlanBlock: Identifiable, Equatable, Sendable {
    public let exerciseIndex: Int
    public let exerciseId: UUID
    public let sets: [PlanSet]
    public var id: Int { exerciseIndex }
}

extension PlanWorkout {
    /// 從「動作 → 每個動作幾組、目標」的編輯輸入，指派一致的 0-based index 建立 sets。
    /// 每個 draft 是一個動作區塊，sets 數量＝該動作要做的組數，每組同目標。
    public static func makeSets(from drafts: [ExerciseTargetDraft], makeID: () -> UUID = { UUID() }) -> [PlanSet] {
        var result: [PlanSet] = []
        for (exerciseIndex, draft) in drafts.enumerated() {
            for setIndex in 0..<max(1, draft.setCount) {
                result.append(PlanSet(
                    id: makeID(),
                    exerciseId: draft.exerciseId,
                    exerciseIndex: exerciseIndex,
                    setIndex: setIndex,
                    targetWeight: draft.targetWeight,
                    targetReps: draft.targetReps,
                    restSec: draft.restSec
                ))
            }
        }
        return result
    }
}

/// 排課編輯時的一個動作區塊輸入。
public struct ExerciseTargetDraft: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var exerciseId: UUID
    public var setCount: Int
    public var targetWeight: Weight?
    public var targetReps: Int?
    public var restSec: Int?

    public init(
        id: UUID = UUID(),
        exerciseId: UUID,
        setCount: Int,
        targetWeight: Weight?,
        targetReps: Int?,
        restSec: Int? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.setCount = setCount
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.restSec = restSec
    }
}
