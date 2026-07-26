import Foundation
import PlanDomain
import SharedKernel

/// `WeightExpression` ⇄ SwiftData 三欄位（kind／value／unit）編碼，四個 Set model
/// （TemplateSetModel／RotationSetModel／ProgramSlotSetModel／PlanSetModel）共用，避免重複四份 switch。
/// `.percentOf1RM` 沒有單位（存的是百分比數字），`unit` 欄位留 nil。
enum WeightExpressionCoding {
    static func encode(_ expression: WeightExpression?) -> (kind: String?, value: Double?, unit: String?) {
        switch expression {
        case nil:
            return (nil, nil, nil)
        case .absolute(let weight):
            return ("absolute", weight.value, weight.unit.rawValue)
        case .relativeToLast(let delta):
            return ("relativeToLast", delta.value, delta.unit.rawValue)
        case .percentOf1RM(let percent):
            return ("percentOf1RM", percent, nil)
        }
    }

    static func decode(kind: String?, value: Double?, unitRaw: String?) -> WeightExpression? {
        guard let value else { return nil }
        if kind == "percentOf1RM" { return .percentOf1RM(value) }
        let weight = Weight(value: value, unit: WeightUnit(rawValue: unitRaw ?? "kg") ?? .kg)
        return kind == "relativeToLast" ? .relativeToLast(delta: weight) : .absolute(weight)
    }
}
