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
struct MockLastPerformedWeightLookup: LastPerformedWeightLookup {
    let weight: Weight?
    init(_ weight: Weight? = nil) { self.weight = weight }
    func lastPerformedWeight(exerciseId: UUID) async throws -> Weight? { weight }
}
