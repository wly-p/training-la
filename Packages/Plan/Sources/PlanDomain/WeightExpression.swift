import Foundation
import SharedKernel

/// 重量表達式（逐組屬性）：範本／循環／長期的 spec 存這個；一旦投影/實例化成當日排課，
/// 一律收斂成 `.absolute`（或 nil，查不到歷史/能力值時）——materialize 後的 `PlanWorkout.sets`
/// 不會出現 `.relativeToLast`／`.percentOf1RM`（這個 invariant 由投影用例維持，不是型別強制）。
public enum WeightExpression: Equatable, Sendable {
    case absolute(Weight)
    case relativeToLast(delta: Weight)
    /// 這個階段練「能力值」的 p%（p 為 0–100 的百分比數字）。需要該動作的能力值(1RM)才算得出公斤。
    case percentOf1RM(Double)
}

extension WeightExpression {
    /// 已收斂的具體公斤；只有 `.absolute` 才有值。給材料化層（PlanWorkout）的消費端用。
    public var resolvedWeight: Weight? {
        if case .absolute(let weight) = self { weight } else { nil }
    }
}

/// 某動作最近一次「實際」練的表現：重量 ＋ 是否達標（實際次數 >= 目標次數；無目標快照＝視為達標）。
/// `relativeToLast` 只有「上次達標」才 +delta，沒達標維持上次的重量不進步（見 91-weight-model.md §3）。
public struct LastPerformedSet: Equatable, Sendable {
    public let weight: Weight
    public let metTarget: Bool
    public init(weight: Weight, metTarget: Bool = true) {
        self.weight = weight
        self.metTarget = metTarget
    }
}

/// 查某動作最近一次「實際」練的重量（Training 的紀錄）。Plan package 不依賴 Training，
/// 由 App 層 adapter 實作、注入到投影/實例化 use case。
public protocol LastPerformedWeightLookup: Sendable {
    func lastPerformedWeight(exerciseId: UUID) async throws -> LastPerformedSet?
}

/// 查某動作目前的能力值(1RM)。Plan package 不依賴 Ability，由 App 層 adapter 實作、注入。
public protocol AbilityValueLookup: Sendable {
    func abilityValue(exerciseId: UUID) async throws -> Weight?
}

/// 投影/實例化收斂：把重量表達式算成確定公斤。
/// 絕對值／%1RM／相對上次先各自算出 base，套 `intensityFactor` 後再依器材遞增單位向下取整
/// （順序不能換：倍率套在 base 之後、取整之前，見 91-weight-model.md §5）。
/// 查不到能力值或歷史 ＝ nil（空白待填，不猜一個數字塞進去）。
func resolveWeightExpression(
    _ expression: WeightExpression?,
    weightStep: Double,
    intensityFactor: Double,
    exerciseId: UUID,
    lastPerformedLookup: any LastPerformedWeightLookup,
    abilityValueLookup: any AbilityValueLookup
) async throws -> WeightExpression? {
    let base: Weight?
    switch expression {
    case nil:
        base = nil
    case .absolute(let weight):
        base = weight
    case .percentOf1RM(let percent):
        guard let ability = try await abilityValueLookup.abilityValue(exerciseId: exerciseId) else { return nil }
        base = Weight(value: ability.value * percent / 100, unit: ability.unit)
    case .relativeToLast(let delta):
        guard let last = try await lastPerformedLookup.lastPerformedWeight(exerciseId: exerciseId) else { return nil }
        base = last.metTarget ? Weight(value: last.weight.value + delta.value, unit: last.weight.unit) : last.weight
    }
    guard let base else { return nil }
    let step = weightStep > 0 ? weightStep : 1
    let raw = base.value * intensityFactor
    let stepped = (raw / step).rounded(.down) * step
    return .absolute(Weight(value: max(0, stepped), unit: base.unit))
}

/// 把一份 spec 的 sets（可能帶未收斂表達式）投影成材料化的 `PlanSet` 陣列（一律 `.absolute` 或 nil）。
/// `InstantiateTemplate`／`MaterializeProjectedWorkout`／`ReconcileProgramAssignments`／`StartRotation` 共用。
/// `intensityFactor`：範本沒有倍率概念，呼叫端固定傳 1.0；循環/長期傳 `slot ?? plan` 的覆寫值。
func resolvedPlanSets(
    from sourceSets: [PlanSet],
    catalog: [PlanCatalogExercise],
    intensityFactor: Double,
    lastPerformedLookup: any LastPerformedWeightLookup,
    abilityValueLookup: any AbilityValueLookup,
    makeID: () -> UUID
) async throws -> [PlanSet] {
    let stepByExercise = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0.equipment.weightStep) })
    var result: [PlanSet] = []
    for set in sourceSets {
        let resolved = try await resolveWeightExpression(
            set.targetWeight,
            weightStep: stepByExercise[set.exerciseId] ?? 1,
            intensityFactor: intensityFactor,
            exerciseId: set.exerciseId,
            lastPerformedLookup: lastPerformedLookup,
            abilityValueLookup: abilityValueLookup
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
