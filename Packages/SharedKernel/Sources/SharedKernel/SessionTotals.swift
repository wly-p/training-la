import Foundation

/// 一場（或一段區間）的分項總計。
///
/// **各模式各自累計，不互相換算**——「撐 90 秒」跟「推 100 公斤」之間沒有大小關係，
/// 硬要湊成一個數字只會得到假的總量。非重量模式也不會被偷偷算成 0：
/// 那會讓「今天跑了 5 公里」在摘要裡完全消失。
public struct SessionTotals: Equatable, Sendable {
    /// 只有帶重量的模式進得來（`weightReps` / `bodyweightPlus`）。
    public var volumeKilograms: Double = 0
    public var durationSeconds: Int = 0
    public var distanceMeters: Double = 0
    /// 純次數模式的總次數。
    public var repsOnly: Int = 0

    public init(
        volumeKilograms: Double = 0, durationSeconds: Int = 0,
        distanceMeters: Double = 0, repsOnly: Int = 0
    ) {
        self.volumeKilograms = volumeKilograms
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.repsOnly = repsOnly
    }

    public mutating func add(_ measurement: SetMeasurement) {
        switch measurement {
        case .weightReps, .bodyweightPlus:
            volumeKilograms += measurement.volumeKilograms ?? 0
        case .reps(let count):
            repsOnly += count
        case .duration(let seconds):
            durationSeconds += seconds
        case .distance(let meters):
            distanceMeters += meters
        }
    }

    /// 除了重量之外還有東西可講嗎（決定摘要要不要多印一行）。
    public var hasNonWeightWork: Bool {
        durationSeconds > 0 || distanceMeters > 0 || repsOnly > 0
    }
}

/// 實際 vs 目標的達標判定。
public enum SetMeasurementComparison {
    /// 達標＝各維度都不低於目標。
    ///
    /// **模式不同一律回 nil**：代表動作的追蹤模式在排課之後被改過，
    /// 拿秒數去比公斤沒有意義，判成「沒達標」會是錯的訊號。
    public static func meetsTarget(_ actual: SetMeasurement, target: SetMeasurement) -> Bool? {
        switch (actual, target) {
        case (.weightReps(let aw, let ar), .weightReps(let tw, let tr)):
            aw >= tw && ar >= tr
        case (.bodyweightPlus(let aw, let ar), .bodyweightPlus(let tw, let tr)):
            aw >= tw && ar >= tr
        case (.reps(let a), .reps(let t)):
            a >= t
        case (.duration(let a), .duration(let t)):
            a >= t
        case (.distance(let a), .distance(let t)):
            a >= t
        default:
            nil
        }
    }
}

extension SetMeasurement {
    /// **顯示用**的重量；非重量模式回 nil。
    ///
    /// 這幾個 `display*` 存取子是刻意開的窄口，只給格式化用——不然每個 View 都要寫一次
    /// 五個 case 的 switch。真正需要編譯器守著的地方（聚合、PR 判定、達標比較）
    /// 一律走完整的 switch，**不要**拿這裡的 optional 去繞過它們。
    public var displayWeight: Weight? {
        switch self {
        case .weightReps(let weight, _), .bodyweightPlus(let weight, _): weight
        case .reps, .duration, .distance: nil
        }
    }

    /// **顯示用**的次數；時間／距離模式回 nil。
    public var displayReps: Int? {
        switch self {
        case .weightReps(_, let reps), .bodyweightPlus(_, let reps), .reps(let reps): reps
        case .duration, .distance: nil
        }
    }
}
