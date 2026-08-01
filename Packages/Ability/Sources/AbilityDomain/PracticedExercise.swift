import Foundation
import SharedKernel

/// 一個「有練過」的動作＋最近一次實際表現。能力值清單只列這些動作
/// （不是整個動作庫）——見 05-settings.md B 節。
public struct PracticedExercise: Identifiable, Equatable, Sendable {
    public let exerciseId: UUID
    public let exerciseName: String
    /// 器材：名稱允許重複，而最大重量對「臥推(槓鈴)」和「胸推(機械)」是不同的數字，
    /// 清單上一定要能分辨（見 docs/exercise-glossary.md）。
    public let equipment: Equipment
    /// 這個動作**歷來推過的最大重量**——能力值的建議值直接取它，不套估算公式
    /// （handoff-15 A 節：能力值＝實測最大重量，不是估算 1RM）。
    public let maxWeight: Weight
    /// 最近一次的重量與次數：編輯頁下方「最近一次做到 X × N」用，供使用者判斷建議值合不合理。
    public let lastWeight: Weight
    public let lastReps: Int
    /// 最近一次練這個動作的日期；清單排序用（未設定的按最近訓練日排）。
    public let lastPerformedOn: DayDate

    public var id: UUID { exerciseId }

    public init(
        exerciseId: UUID,
        exerciseName: String,
        equipment: Equipment,
        maxWeight: Weight,
        lastWeight: Weight,
        lastReps: Int,
        lastPerformedOn: DayDate
    ) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.maxWeight = maxWeight
        self.lastWeight = lastWeight
        self.lastReps = lastReps
        self.lastPerformedOn = lastPerformedOn
    }
}

/// 查「有練過的動作」清單（Training 的訓練紀錄 ＋ Spec 的動作名稱）。
/// Ability package 不依賴 Training/Spec，由 App 層 adapter 實作、注入。
public protocol PracticedExerciseLister: Sendable {
    func practicedExercises() async throws -> [PracticedExercise]
}
