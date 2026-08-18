import Foundation
import SharedKernel

/// 長期課表：一個「N 天週期」的計畫，內容按「第幾天」排（不綁星期幾）。
/// 缺席的 day＝該天休息。成員是 copy 快照，改範本不影響、改它也不影響範本。
/// N 自訂：5 天循環、10 天課表、28 天漸進（＝原「多週」效果、但不綁週一）皆可表達。
public struct Program: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var source: ContentSource
    public var orderIndex: Int
    /// 週期天數（至少 1）。
    public var cycleLength: Int
    /// 第 dayIndex 天（0-based, 0..<cycleLength）→ workout；缺＝休息。
    public var days: [Int: WorkoutSpec]
    /// 這份課表的強度倍率（預設 1.0＝基準）。格子（`WorkoutSpec.intensityFactor`）可選填覆寫。
    public var intensityFactor: Double
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        name: String,
        source: ContentSource = .user,
        orderIndex: Int,
        cycleLength: Int = 7,
        days: [Int: WorkoutSpec] = [:],
        intensityFactor: Double = 1.0,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.orderIndex = orderIndex
        self.cycleLength = max(1, cycleLength)
        self.days = days
        self.intensityFactor = intensityFactor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 這份課表第 dayIndex 天排的 workout（超界或休息日＝nil）。
    public func workout(dayIndex: Int) -> WorkoutSpec? {
        guard (0..<cycleLength).contains(dayIndex) else { return nil }
        return days[dayIndex]
    }
}

/// 套用模式：跑一次（N 天結束）或重複（跑完回第 1 天續、無限）。
public enum ProgramRunMode: String, Codable, Sendable {
    case once
    case repeating
}

/// 套用一份長期課表：綁起始日 + 模式。投影來源；可並存多個 active。
/// 停用＝刪除這筆 assignment（過去已落地的真實紀錄不受影響）。
public struct ProgramAssignment: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var programId: UUID
    /// 課表第 1 天（第 0 天）對齊到的起始日。
    public var startDate: DayDate
    public var mode: ProgramRunMode
    /// 補登進度：已補到哪一天（含）。nil＝還沒補過。冪等掃描用。
    public var lastReconciledDate: DayDate?
    /// 單日覆寫：日期 → 那天實際要用的 cycleDay。給「把明天的腿日挪到今天」這種臨時搬動用。
    /// 只影響列出來的那幾天，週期公式本身不動 ⇒ 沒被覆寫的日子節奏照舊（13f 左那句
    /// 「挪動只影響這一輪，之後的節奏照舊」就是靠這個成立）。
    public var dayOverrides: [DayDate: Int]

    public init(
        id: UUID,
        programId: UUID,
        startDate: DayDate,
        mode: ProgramRunMode,
        lastReconciledDate: DayDate? = nil,
        dayOverrides: [DayDate: Int] = [:]
    ) {
        self.id = id
        self.programId = programId
        self.startDate = startDate
        self.mode = mode
        self.lastReconciledDate = lastReconciledDate
        self.dayOverrides = dayOverrides
    }
}

// MARK: - 週期對位（投影／補登的核心）

extension ProgramAssignment {
    /// 給定某日期，算它落在這份套用的「第幾天」（0-based，從起始日算 offset）。
    /// 起始日之前＝nil；once 模式 offset 超過週期天數＝nil；repeating 模式對 cycleLength 取模。
    ///
    /// 這是所有投影的單一咽喉點（今日排課、休息日、月曆），所以 `dayOverrides` 只在這裡套一次，
    /// 其他呼叫端不必知道有搬動這回事。
    /// - Parameter cycleLength: 對應 program 的週期天數。
    public func cycleDay(for date: DayDate, cycleLength: Int) -> Int? {
        guard cycleLength > 0 else { return nil }
        // 覆寫優先，且不受「起始日之前／once 已結束」限制——搬動是使用者明確指定的那一天。
        if let overridden = dayOverrides[date] {
            return (0..<cycleLength).contains(overridden) ? overridden : nil
        }
        guard date >= startDate else { return nil }
        let offset = startDate.days(to: date)   // date >= startDate ⇒ offset >= 0
        switch mode {
        case .once:
            return offset < cycleLength ? offset : nil
        case .repeating:
            return offset % cycleLength
        }
    }
}
