import SharedKernel
import TrainingDomain

enum WeightDisplay {
    /// 60.0 → "60"、62.5 → "62.5"。
    /// 實作在 `Weight.formatted`（SharedKernel）——細級距會帶浮點雜訊，
    /// 格式化規則只能有一份，不然兩邊會不一致。
    static func value(_ value: Double) -> String {
        Weight.formatted(value)
    }

    static func weight(_ weight: Weight) -> String {
        "\(value(weight.value))\(weight.unit.rawValue)"
    }

    /// 一個區塊的摘要："60kg × 8, 8, 6"（重量取第一組；混重量時逐組列出）
    static func summary(of sets: [WorkoutSet]) -> String {
        guard let first = sets.first else { return "" }
        let sameWeight = sets.allSatisfy { $0.weight == first.weight }
        if sameWeight {
            let reps = sets.map { "\($0.reps)" }.joined(separator: ", ")
            return "\(weight(first.weight)) × \(reps)"
        }
        return sets.map { "\(weight($0.weight))×\($0.reps)" }.joined(separator: ", ")
    }
}
