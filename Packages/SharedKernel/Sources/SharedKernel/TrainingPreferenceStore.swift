import Foundation

/// 訓練偏好的持久化：調整重量與休息時間的級距。跟 ``WeightUnitPreferenceStoring`` 同 pattern。
///
/// 級距完全由使用者決定——原本重量級距來自 `Equipment.weightStep`（依器材猜：槓鈴 2.5、
/// 啞鈴 2、機械 5），但那是對典型健身房的假設，不是使用者的真實器材：用 170g 卡扣做精細
/// 調整的人，被寫死的 2.5 直接把精細度吃掉。
///
/// 放 SharedKernel 而非 Settings：Training / Plan / History 都要讀它，而它們不該相依 Settings。
public protocol TrainingPreferenceStoring: Sendable {
    func loadWeightStep() -> Double
    func saveWeightStep(_ step: Double)
    func loadRestStep() -> Int
    func saveRestStep(_ step: Int)
}

extension TrainingPreferenceStoring {
    /// 沒設定過時的重量級距，延續改動前的行為（原本訓練頁寫死 kg 2.5）。
    public static var defaultWeightStep: Double { 2.5 }
    /// 重量級距的合法範圍：要能細到一個卡扣（0.17kg），上限 20 讓滾輪清單不會退化成幾格。
    public static var weightStepRange: ClosedRange<Double> { 0.01...20 }
    /// 沒設定過時的休息級距，延續改動前的行為（原本 ± 按鈕寫死 30 秒）。
    public static var defaultRestStep: Int { 30 }
    /// 休息級距的合法範圍。上限給到 5 分鐘——自訂再大是使用者自己的事，但不能是 0 或負數。
    public static var restStepRange: ClosedRange<Int> { 1...300 }
}

/// UserDefaults 實作。讀出來的值一律夾回合法範圍——舊版寫進去的壞值不該讓 UI 壞掉。
public struct UserDefaultsTrainingPreferenceStore: TrainingPreferenceStoring {
    // UserDefaults 執行緒安全但未標 Sendable（對齊 UserDefaultsLanguageStore 的既有寫法）。
    nonisolated(unsafe) private let defaults: UserDefaults
    private let weightStepKey = "settings.weightStep"
    private let restStepKey = "settings.restStep"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadWeightStep() -> Double {
        let stored = defaults.double(forKey: weightStepKey)
        // double(forKey:) 對「沒存過」回 0，正好也是非法值，同一條判斷擋掉。
        guard Self.weightStepRange.contains(stored) else { return Self.defaultWeightStep }
        return stored
    }

    public func saveWeightStep(_ step: Double) {
        guard Self.weightStepRange.contains(step) else { return }
        defaults.set(step, forKey: weightStepKey)
    }

    public func loadRestStep() -> Int {
        let stored = defaults.integer(forKey: restStepKey)
        guard Self.restStepRange.contains(stored) else { return Self.defaultRestStep }
        return stored
    }

    public func saveRestStep(_ step: Int) {
        guard Self.restStepRange.contains(step) else { return }
        defaults.set(step, forKey: restStepKey)
    }
}

/// 測試 / UI 測試用：不落地，每次啟動乾淨。
public final class InMemoryTrainingPreferenceStore: TrainingPreferenceStoring, @unchecked Sendable {
    private var weightStep: Double
    private var restStep: Int

    public init(
        weightStep: Double = InMemoryTrainingPreferenceStore.defaultWeightStep,
        restStep: Int = InMemoryTrainingPreferenceStore.defaultRestStep
    ) {
        self.weightStep = weightStep
        self.restStep = restStep
    }

    public func loadWeightStep() -> Double { weightStep }
    public func saveWeightStep(_ step: Double) {
        guard Self.weightStepRange.contains(step) else { return }
        weightStep = step
    }

    public func loadRestStep() -> Int { restStep }
    public func saveRestStep(_ step: Int) {
        guard Self.restStepRange.contains(step) else { return }
        restStep = step
    }
}
