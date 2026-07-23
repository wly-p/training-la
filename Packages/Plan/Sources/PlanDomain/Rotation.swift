import Foundation
import SharedKernel

/// 環尋循環裡的一個 workout（可攜複本 copy：自帶名稱與目標，不引用範本）。
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

/// 環尋循環（進度制、不綁日期）：有序 workout + 目前輪到的游標。MVP 為單一 active 循環。
public struct Rotation: Equatable, Sendable {
    public var workouts: [WorkoutSpec]
    public var cursor: Int

    public init(workouts: [WorkoutSpec] = [], cursor: Int = 0) {
        self.workouts = workouts
        self.cursor = Rotation.clamp(cursor, count: workouts.count)
    }

    /// 目前輪到的 workout；空循環＝nil。
    public var current: WorkoutSpec? {
        workouts.isEmpty ? nil : workouts[Rotation.clamp(cursor, count: workouts.count)]
    }

    /// 游標往下一張（做完回到第一張）。
    public func advanced() -> Rotation {
        guard !workouts.isEmpty else { return self }
        return Rotation(workouts: workouts, cursor: (cursor + 1) % workouts.count)
    }

    private static func clamp(_ cursor: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((cursor % count) + count) % count
    }
}
