import Foundation
import SharedKernel

public struct ListAbilityValues: Sendable {
    private let repository: any AbilityValueRepository
    public init(repository: any AbilityValueRepository) { self.repository = repository }
    public func callAsFunction() async throws -> [AbilityValue] { try await repository.all() }
}

public struct GetAbilityValue: Sendable {
    private let repository: any AbilityValueRepository
    public init(repository: any AbilityValueRepository) { self.repository = repository }
    public func callAsFunction(exerciseId: UUID) async throws -> AbilityValue? {
        try await repository.get(exerciseId: exerciseId)
    }
}

/// 設定／更新某動作的能力值（手動填，或接受推算建議時 source 傳 `.estimated`）。
public struct SetAbilityValue: Sendable {
    private let repository: any AbilityValueRepository
    private let now: @Sendable () -> Date

    public init(
        repository: any AbilityValueRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.now = now
    }

    @discardableResult
    public func callAsFunction(
        exerciseId: UUID,
        value: Weight,
        source: AbilityValueSource = .manual
    ) async throws -> AbilityValue {
        let ability = AbilityValue(exerciseId: exerciseId, value: value, source: source, updatedAt: now())
        try await repository.save(ability)
        return ability
    }
}

public struct DeleteAbilityValue: Sendable {
    private let repository: any AbilityValueRepository
    public init(repository: any AbilityValueRepository) { self.repository = repository }
    public func callAsFunction(exerciseId: UUID) async throws { try await repository.delete(exerciseId: exerciseId) }
}

/// 從最近一次訓練紀錄（weight × reps）推算 1RM（Epley 公式），供「建議更新到 X」banner 用。
/// 純函式：只做一組換算，不查任何 repository——最近一次紀錄由呼叫端（Training adapter）提供。
public struct SuggestAbilityValue: Sendable {
    public init() {}

    public func callAsFunction(weight: Weight, reps: Int) -> Weight {
        guard reps > 1 else { return weight }
        let estimated = weight.value * (1 + Double(reps) / 30.0)
        return Weight(value: estimated, unit: weight.unit)
    }
}
