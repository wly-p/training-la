import Foundation
import SharedKernel

/// 循環課表（進度制、不綁日期）：有序 workout + 目前輪到的游標。
/// 可有多組並行；每組各自啟用（isActive）與進度（cursor）。停用時游標歸零（見 SetRotationActive）。
public struct Rotation: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var workouts: [WorkoutSpec]
    public var cursor: Int
    /// 是否啟用：只有啟用中的循環會出現在訓練首頁「今天輪到 X」。
    public var isActive: Bool
    /// 清單排序。
    public var orderIndex: Int
    /// 累計已開始的訓練次數（每次 `StartRotation` +1）。詳情頁「已完成 N 次訓練」與「N 輪」由此算。
    public var completedCount: Int

    public init(
        id: UUID = UUID(),
        name: String = "",
        workouts: [WorkoutSpec] = [],
        cursor: Int = 0,
        isActive: Bool = true,
        orderIndex: Int = 0,
        completedCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.workouts = workouts
        self.cursor = Rotation.clamp(cursor, count: workouts.count)
        self.isActive = isActive
        self.orderIndex = orderIndex
        self.completedCount = max(0, completedCount)
    }

    /// 目前輪到的 workout；空循環＝nil。
    public var current: WorkoutSpec? {
        workouts.isEmpty ? nil : workouts[Rotation.clamp(cursor, count: workouts.count)]
    }

    /// 已完成的整輪數＝總次數 ÷ 範本數（無條件捨去）。空循環＝0。
    public var roundsCompleted: Int {
        workouts.isEmpty ? 0 : completedCount / workouts.count
    }

    /// 游標往下一張（做完回到第一張），其餘欄位不變。**不計入次數**（給「跳到下一個範本」用）。
    public func advanced() -> Rotation {
        guard !workouts.isEmpty else { return self }
        var next = self
        next.cursor = (cursor + 1) % workouts.count
        return next
    }

    private static func clamp(_ cursor: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((cursor % count) + count) % count
    }
}
