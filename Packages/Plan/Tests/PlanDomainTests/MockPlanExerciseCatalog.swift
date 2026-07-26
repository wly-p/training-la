import Foundation
import PlanDomain
import SharedKernel

/// 空動作庫（測試預設不需要器材遞增單位時用）。
struct MockPlanExerciseCatalog: PlanExerciseCatalog {
    let items: [PlanCatalogExercise]
    init(_ items: [PlanCatalogExercise] = []) { self.items = items }
    func exercises() async throws -> [PlanCatalogExercise] { items }
}

/// 固定回某個重量（或 nil＝查不到歷史）的「上次紀錄」查詢，測試投影收斂用。
/// `metTarget` 預設 true（維持舊測試「有查到就 +delta」的行為）；測「上次未達標」的測試明確傳 false。
struct MockLastPerformedWeightLookup: LastPerformedWeightLookup {
    let performance: LastPerformedSet?
    init(_ weight: Weight? = nil, metTarget: Bool = true) {
        self.performance = weight.map { LastPerformedSet(weight: $0, metTarget: metTarget) }
    }
    func lastPerformedWeight(exerciseId: UUID) async throws -> LastPerformedSet? { performance }
}

/// 固定回某個能力值（或 nil＝沒設定）的查詢，測試 %1RM 收斂用。
struct MockAbilityValueLookup: AbilityValueLookup {
    let weight: Weight?
    init(_ weight: Weight? = nil) { self.weight = weight }
    func abilityValue(exerciseId: UUID) async throws -> Weight? { weight }
}
