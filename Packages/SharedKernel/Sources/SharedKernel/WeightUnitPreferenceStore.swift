import Foundation

/// 使用者預設重量單位的持久化。跟 ``LanguagePreferenceStoring`` 同 pattern：
/// 單一偏好、protocol 化方便注入 mock，不值得為它拉一整套 repository。
///
/// 這個偏好只決定**輸入與顯示時的預設單位**；每筆 ``Weight`` 仍各自存下輸入當下的單位，
/// 換算發生在比較與顯示的時候（見 ``Weight`` 的運算子）。
///
/// 放 SharedKernel 而非 Settings：Training 記錄新組時要用它決定草稿單位，
/// 而 Training 不該相依 Settings。`Sendable` 同理——可能在非 MainActor context 讀取。
public protocol WeightUnitPreferenceStoring: Sendable {
    func load() -> WeightUnit
    func save(_ unit: WeightUnit)
}

/// UserDefaults 實作。沒設定過時回 `.kg`——延續改動前的行為，既有使用者不會感覺到變化。
public struct UserDefaultsWeightUnitStore: WeightUnitPreferenceStoring {
    // UserDefaults 執行緒安全但未標 Sendable（對齊 UserDefaultsLanguageStore 的既有寫法）。
    nonisolated(unsafe) private let defaults: UserDefaults
    private let key = "settings.weightUnit"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> WeightUnit {
        defaults.string(forKey: key).flatMap(WeightUnit.init(rawValue:)) ?? .kg
    }

    public func save(_ unit: WeightUnit) {
        defaults.set(unit.rawValue, forKey: key)
    }
}

/// 測試 / UI 測試用：不落地，每次啟動乾淨。
public final class InMemoryWeightUnitStore: WeightUnitPreferenceStoring, @unchecked Sendable {
    private var stored: WeightUnit

    public init(initial: WeightUnit = .kg) {
        self.stored = initial
    }

    public func load() -> WeightUnit { stored }
    public func save(_ unit: WeightUnit) { stored = unit }
}
