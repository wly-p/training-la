import Foundation
import SharedKernel

/// 重量表達式（逐組屬性）：範本／循環／長期的 spec 存這個；一旦投影/實例化成當日排課，
/// 一律收斂成 `.absolute`（或 nil，查不到歷史時）——materialize 後的 `PlanWorkout.sets`
/// 不會出現 `.relativeToLast`（這個 invariant 由投影用例維持，不是型別強制）。
/// 這次設計不做 %1RM（見動作庫 v3 README J 節），只有絕對值／相對上次兩種。
public enum WeightExpression: Equatable, Sendable {
    case absolute(Weight)
    case relativeToLast(delta: Weight)
}

extension WeightExpression {
    /// 已收斂的具體公斤；只有 `.absolute` 才有值。給材料化層（PlanWorkout）的消費端用。
    public var resolvedWeight: Weight? {
        if case .absolute(let weight) = self { weight } else { nil }
    }
}

/// 查某動作最近一次「實際」練的重量（Training 的紀錄）。Plan package 不依賴 Training，
/// 由 App 層 adapter 實作、注入到投影/實例化 use case。
public protocol LastPerformedWeightLookup: Sendable {
    func lastPerformedWeight(exerciseId: UUID) async throws -> Weight?
}

/// 投影/實例化收斂：把重量表達式算成確定公斤。絕對值直接用；相對上次查 `lookup` + delta，
/// 依器材的遞增單位向下取整；查不到歷史 ＝ nil（空白待填，不猜一個數字塞進去）。
func resolveWeightExpression(
    _ expression: WeightExpression?,
    weightStep: Double,
    exerciseId: UUID,
    lookup: any LastPerformedWeightLookup
) async throws -> WeightExpression? {
    switch expression {
    case nil, .absolute:
        return expression
    case .relativeToLast(let delta):
        guard let last = try await lookup.lastPerformedWeight(exerciseId: exerciseId) else { return nil }
        let step = weightStep > 0 ? weightStep : 1
        let raw = last.value + delta.value
        let stepped = (raw / step).rounded(.down) * step
        return .absolute(Weight(value: max(0, stepped), unit: last.unit))
    }
}

/// 把一份 spec 的 sets（可能帶未收斂表達式）投影成材料化的 `PlanSet` 陣列（一律 `.absolute` 或 nil）。
/// `InstantiateTemplate`／`MaterializeProjectedWorkout`／`ReconcileProgramAssignments`／`StartRotation` 共用。
func resolvedPlanSets(
    from sourceSets: [PlanSet],
    catalog: [PlanCatalogExercise],
    lookup: any LastPerformedWeightLookup,
    makeID: () -> UUID
) async throws -> [PlanSet] {
    let stepByExercise = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0.equipment.weightStep) })
    var result: [PlanSet] = []
    for set in sourceSets {
        let resolved = try await resolveWeightExpression(
            set.targetWeight,
            weightStep: stepByExercise[set.exerciseId] ?? 1,
            exerciseId: set.exerciseId,
            lookup: lookup
        )
        result.append(PlanSet(
            id: makeID(),
            exerciseId: set.exerciseId,
            exerciseIndex: set.exerciseIndex,
            setIndex: set.setIndex,
            targetWeight: resolved,
            targetReps: set.targetReps,
            restSec: set.restSec
        ))
    }
    return result
}
