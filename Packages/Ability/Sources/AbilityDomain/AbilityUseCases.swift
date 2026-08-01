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

/// 能力值的建議值＝這個動作**歷來推過的最大重量**，原樣回傳。
///
/// 刻意不套 Epley／Brzycki 之類的估算公式（handoff-15 A 節）：「能力值」的定義是
/// 實際推過的最大重量，不是推估的 1RM。套公式會產生兩個問題——建議一個從沒推起來過的
/// 數字，以及 `100kg × 2` 被算成 `106.67` 這種裝不出來的重量。
///
/// 保留成一個 use case 而不是直接讀欄位，是因為「建議值怎麼來」屬於 domain 決策，
/// 之後若要加條件（例如只看近三個月）改這裡就好。
public struct SuggestAbilityValue: Sendable {
    public init() {}

    public func callAsFunction(maxWeight: Weight) -> Weight { maxWeight }
}
