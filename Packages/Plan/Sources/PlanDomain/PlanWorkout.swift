import Foundation
import SharedKernel

/// 排課的來源。多週長期課表補登時，用 (origin, assignmentId, date) 判斷是否已建過避免重複。
public enum PlanOrigin: String, Codable, Sendable {
    case manual     // 手動當日排課
    case template   // 從課表範本實例化
    case program    // 多週長期課表投影落地
    case rotation   // 循環課表落地
}

/// 一次排課（個人層 plan_workout）：一定綁定某一天，由課表範本實例化或手動建立。
/// aggregate root：連同 sets 整包寫入/取代，對齊 API。
public struct PlanWorkout: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String?
    /// 指定哪一天做。
    public var date: DayDate
    public var status: PlanWorkoutStatus
    /// 來源課表範本；nil＝手動建立的一次性排課。
    public var templateId: UUID?
    /// 這張排課怎麼來的。
    public var origin: PlanOrigin
    /// 若來自多週長期課表投影落地，指向對應的 ProgramAssignment；用於補登去重。
    public var assignmentId: UUID?
    /// 同一天多張排課的排序。
    public var orderIndex: Int
    /// 依 (exerciseIndex, setIndex) 排序的目標。
    public var sets: [PlanSet]

    public init(
        id: UUID,
        name: String?,
        date: DayDate,
        status: PlanWorkoutStatus = .notStarted,
        templateId: UUID? = nil,
        origin: PlanOrigin = .manual,
        assignmentId: UUID? = nil,
        orderIndex: Int,
        sets: [PlanSet] = []
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.status = status
        self.templateId = templateId
        self.origin = origin
        self.assignmentId = assignmentId
        self.orderIndex = orderIndex
        self.sets = sets
    }

    /// 依 exerciseIndex 分組、組內依 setIndex 排序。
    public var blocks: [PlanBlock] { sets.planBlocks }
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

extension Array where Element == PlanSet {
    /// 依 exerciseIndex 分組、組內依 setIndex 排序。PlanWorkout 與課表範本共用。
    public var planBlocks: [PlanBlock] {
        Dictionary(grouping: self, by: \.exerciseIndex)
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

extension PlanSet {
    /// 從「動作 → 每個動作幾組、目標」的編輯輸入，指派一致的 0-based index 建立 sets。
    /// 每個 draft 是一個動作區塊，sets 數量＝該動作要做的組數，每組同目標。PlanWorkout 與範本共用。
    public static func make(from drafts: [ExerciseTargetDraft], makeID: () -> UUID = { UUID() }) -> [PlanSet] {
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
