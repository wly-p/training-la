import Foundation

/// 重量輸入的可選值域。
///
/// 原本全 app 五處各自寫死 `stride(from: 0, through: 300, by:)`，有兩個問題：
/// 300kg 對深蹲／硬舉／腿推不夠（能力值 1RM 那處更明顯），而且值域跟單位脫鉤——
/// 清單永遠是 0…300 這串數字、單位只是貼在後面的標籤，切到 lb 時實際上限
/// 變成 300 lb ＝ 136 kg，比 kg 模式還低。
public enum WeightRange {
    /// 依單位的上限：kg 500、lb 1100（約 500kg）。
    public static func upperBound(for unit: WeightUnit) -> Double {
        switch unit {
        case .kg: 500
        case .lb: 1100
        }
    }

    /// 給選擇器滾輪用的可選值清單。`step` 由使用者的級距偏好決定。
    ///
    /// 清單筆數 = 上限 / 級距，所以級距很細時清單會很長（0.17 → 約 2900 筆）。
    /// `DualValuePicker` 只渲染當前 index ±2 列，長度不影響繪製成本，但它的
    /// `index(of:in:)` 是線性搜尋，必要時再換二分搜尋。
    public static func values(for unit: WeightUnit, step: Double) -> [Double] {
        let step = step > 0 ? step : 1
        return Array(stride(from: 0, through: upperBound(for: unit), by: step))
    }

    /// 把數值夾在合法範圍內（± 快捷、輸入框都用得到）。
    public static func clamped(_ value: Double, unit: WeightUnit) -> Double {
        min(max(0, value), upperBound(for: unit))
    }

    /// 依級距向下取整（投影收斂、強度倍率預覽共用）。
    ///
    /// 加容差再 floor：`value` 剛好落在 `step` 的整數倍上時，浮點除法可能算出 99.999…
    /// 而少掉一階（實測 17.0 / 0.17 會收斂成 16.83），細級距特別容易中。
    ///
    /// 收斂成一份是刻意的——排課的強度倍率預覽必須跟實際材料化的結果算出同一個數字，
    /// 兩邊各寫各的就會出現「預覽說 90、實際排出來 87.5」。
    public static func steppedDown(_ value: Double, step: Double) -> Double {
        let step = step > 0 ? step : 1
        return max(0, (value / step + 1e-9).rounded(.down) * step)
    }
}
