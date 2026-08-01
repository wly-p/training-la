import Foundation
import SharedKernel

/// 一個「有練過」的動作＋最近一次實際表現。能力值清單只列這些動作
/// （不是整個動作庫）——見 05-settings.md B 節。
public struct PracticedExercise: Identifiable, Equatable, Sendable {
    public let exerciseId: UUID
    public let exerciseName: String
    /// 器材：名稱允許重複，而 1RM 對「臥推(槓鈴)」和「胸推(機械)」是不同的數字，
    /// 清單上一定要能分辨（見 docs/exercise-glossary.md）。
    public let equipment: Equipment
    public let lastWeight: Weight
    public let lastReps: Int

    public var id: UUID { exerciseId }

    public init(
        exerciseId: UUID,
        exerciseName: String,
        equipment: Equipment,
        lastWeight: Weight,
        lastReps: Int
    ) {
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.lastWeight = lastWeight
        self.lastReps = lastReps
    }
}

/// 查「有練過的動作」清單（Training 的訓練紀錄 ＋ Spec 的動作名稱）。
/// Ability package 不依賴 Training/Spec，由 App 層 adapter 實作、注入。
public protocol PracticedExerciseLister: Sendable {
    func practicedExercises() async throws -> [PracticedExercise]
}
