import Foundation
import SharedKernel

/// 可攜的 workout 定義（copy：自帶名稱與目標，不引用範本）。
/// 循環課表 (Rotation) 與多週長期課表 (Program) 的週格子共用。
public struct WorkoutSpec: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var sets: [PlanSet]
    /// 這一格的強度倍率覆寫；nil＝繼承所屬計畫（Rotation/Program）的 `intensityFactor`
    /// （見 91-weight-model.md §4：兩層就好，不要三層）。
    public var intensityFactor: Double?

    public init(id: UUID = UUID(), name: String, sets: [PlanSet] = [], intensityFactor: Double? = nil) {
        self.id = id
        self.name = name
        self.sets = sets
        self.intensityFactor = intensityFactor
    }

    /// 依 exerciseIndex 分組、組內依 setIndex 排序。
    public var blocks: [PlanBlock] { sets.planBlocks }
}
