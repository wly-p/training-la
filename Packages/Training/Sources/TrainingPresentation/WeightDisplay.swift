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

    /// 一個區塊的摘要："60kg × 8, 8, 6"（重量取第一組；混重量時逐組列出）。
    ///
    /// 非重量模式（時間／距離／純次數）的排版屬於 B2-ui 那張設計票，這裡先只處理帶重量的組；
    /// 沒有 B2-ui 就建立不了非重量模式的動作，所以現階段走不到那條路。
    static func summary(of sets: [WorkoutSet]) -> String {
        let weighted = sets.compactMap { set -> (weight: Weight, reps: Int)? in
            guard let w = set.measurement.displayWeight, let r = set.measurement.displayReps
            else { return nil }
            return (w, r)
        }
        guard let first = weighted.first else { return "" }
        let sameWeight = weighted.allSatisfy { $0.weight == first.weight }
        if sameWeight {
            let reps = weighted.map { "\($0.reps)" }.joined(separator: ", ")
            return "\(weight(first.weight)) × \(reps)"
        }
        return weighted.map { "\(weight($0.weight))×\($0.reps)" }.joined(separator: ", ")
    }
}
