import Foundation
import SharedKernel

/// 能力值的來源：手動填入，或依最近一次訓練紀錄推算（`SuggestAbilityValue`）。
public enum AbilityValueSource: String, Codable, Sendable {
    case manual
    case estimated
}

/// 使用者的能力值（1RM／訓練最大值）：每個動作一筆，是「你的」不是「動作的」，
/// 不屬於 Spec（動作定義）也不屬於 Plan（排程）——見 v6 設計 91-weight-model.md §2。
/// 以 `exerciseId` 為唯一身分（一動作一筆，upsert 語意，不是歷史 log）。
public struct AbilityValue: Identifiable, Equatable, Sendable {
    public var exerciseId: UUID
    public var value: Weight
    public var source: AbilityValueSource
    public var updatedAt: Date

    public var id: UUID { exerciseId }

    public init(exerciseId: UUID, value: Weight, source: AbilityValueSource = .manual, updatedAt: Date = Date()) {
        self.exerciseId = exerciseId
        self.value = value
        self.source = source
        self.updatedAt = updatedAt
    }
}
