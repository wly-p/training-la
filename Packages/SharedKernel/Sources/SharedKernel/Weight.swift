/// 重量：存輸入當下的單位為真實來源，kg/lb 換算只在顯示層。
public struct Weight: Equatable, Hashable, Codable, Sendable {
    public var value: Double
    public var unit: WeightUnit

    public init(value: Double, unit: WeightUnit) {
        self.value = value
        self.unit = unit
    }
}

public enum WeightUnit: String, CaseIterable, Codable, Sendable {
    case kg
    case lb
}
