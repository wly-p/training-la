import Foundation
import PlanDomain
import SharedKernel

/// `WeightExpression` ⇄ SwiftData 三欄位（kind／value／unit）編碼，四個 Set model
/// （TemplateSetModel／RotationSetModel／ProgramSlotSetModel／PlanSetModel）共用，避免重複四份 switch。
/// `.percentOfMax` 沒有單位（存的是百分比數字），`unit` 欄位留 nil。
/// 它的 kind 字串**維持舊值 `"percentOf1RM"`**——改字串等於讓既有資料解不出來。
enum WeightExpressionCoding {
    static func encode(_ expression: WeightExpression?) -> (kind: String?, value: Double?, unit: String?) {
        switch expression {
        case nil:
            return (nil, nil, nil)
        case .absolute(let weight):
            return ("absolute", weight.value, weight.unit.rawValue)
        case .relativeToLast(let delta):
            return ("relativeToLast", delta.value, delta.unit.rawValue)
        case .percentOfMax(let percent):
            return ("percentOf1RM", percent, nil)
        }
    }

    static func decode(kind: String?, value: Double?, unitRaw: String?) -> WeightExpression? {
        guard let value else { return nil }
        // 兩個字串都收：舊資料是 percentOf1RM，未來若改寫成新名也不會壞。
        if kind == "percentOf1RM" || kind == "percentOfMax" { return .percentOfMax(value) }
        let weight = Weight(value: value, unit: WeightUnit(rawValue: unitRaw ?? "kg") ?? .kg)
        return kind == "relativeToLast" ? .relativeToLast(delta: weight) : .absolute(weight)
    }
}

/// `WeightSourceInfo` ⇄ 單欄 JSON 字串編碼（只有 `PlanSetModel` 用得到——只有材料化排課需要留這份
/// 「數字怎麼來的」快照；範本/循環/長期的 spec set 從不設這個欄位）。
enum WeightSourceInfoCoding {
    static func encode(_ info: WeightSourceInfo?) -> String? {
        guard let info, let data = try? JSONEncoder().encode(info) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> WeightSourceInfo? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WeightSourceInfo.self, from: data)
    }
}
