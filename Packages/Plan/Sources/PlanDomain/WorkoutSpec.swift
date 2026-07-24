import Foundation
import SharedKernel

/// 可攜的 workout 定義（copy：自帶名稱與目標，不引用範本）。
/// 循環課表 (Rotation) 與多週長期課表 (Program) 的週格子共用。
public struct WorkoutSpec: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var sets: [PlanSet]

    public init(id: UUID = UUID(), name: String, sets: [PlanSet] = []) {
        self.id = id
        self.name = name
        self.sets = sets
    }

    /// 依 exerciseIndex 分組、組內依 setIndex 排序。
    public var blocks: [PlanBlock] { sets.planBlocks }
}
