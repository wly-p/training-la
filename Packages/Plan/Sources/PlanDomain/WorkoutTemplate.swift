import Foundation
import SharedKernel

/// 課表範本：可重複使用、無日期、無狀態的目標藍圖。
/// 訓練時實例化成當日 `PlanWorkout`（copy sets 快照），範本本身永遠可編輯。
public struct WorkoutTemplate: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// 內容來源：自建（.user）或線上公開（.official）。
    public var source: ContentSource
    /// 清單排序。
    public var orderIndex: Int
    /// 依 (exerciseIndex, setIndex) 排序的目標（複用 PlanSet）。
    public var sets: [PlanSet]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        name: String,
        source: ContentSource = .user,
        orderIndex: Int,
        sets: [PlanSet] = [],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.orderIndex = orderIndex
        self.sets = sets
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 依 exerciseIndex 分組、組內依 setIndex 排序。
    public var blocks: [PlanBlock] { sets.planBlocks }
}
