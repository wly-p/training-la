import Foundation
import SharedKernel

/// `SetMeasurement` ⇄ SwiftData 扁平欄位的編碼。
///
/// Domain 用 enum（型別上就構不出非法組合），Data 存扁平欄位——這是專案裡既有的分工，
/// 見 `PlanData/WeightExpressionCoding`。不要在 `@Model` 上直接放 enum：
/// 那會讓欄位的遷移與查詢都變麻煩，而 `#Predicate` 也吃不到。
///
/// ## 遷移
///
/// `weightValue` / `weightUnitRaw` / `reps` 三個欄位**原封不動沿用**，只新增
/// `modeRaw`（預設 `"weightReps"`）／`durationSec`／`distanceM`。
/// 舊資料的 `modeRaw` 會補上預設值，decode 出來就是 `.weightReps(舊 weightValue, 舊 reps)`，
/// 走 SwiftData 輕量遷移，零轉檔。
enum SetMeasurementCoding {
    struct Columns {
        var modeRaw: String
        var weightValue: Double
        var weightUnitRaw: String
        var reps: Int
        var durationSec: Int?
        var distanceM: Double?
    }

    static func encode(_ measurement: SetMeasurement) -> Columns {
        switch measurement {
        case .weightReps(let weight, let reps):
            Columns(modeRaw: TrackingMode.weightReps.rawValue,
                    weightValue: weight.value, weightUnitRaw: weight.unit.rawValue,
                    reps: reps, durationSec: nil, distanceM: nil)
        case .bodyweightPlus(let added, let reps):
            Columns(modeRaw: TrackingMode.bodyweightPlus.rawValue,
                    weightValue: added.value, weightUnitRaw: added.unit.rawValue,
                    reps: reps, durationSec: nil, distanceM: nil)
        case .reps(let count):
            Columns(modeRaw: TrackingMode.reps.rawValue,
                    weightValue: 0, weightUnitRaw: WeightUnit.kg.rawValue,
                    reps: count, durationSec: nil, distanceM: nil)
        case .duration(let seconds):
            Columns(modeRaw: TrackingMode.duration.rawValue,
                    weightValue: 0, weightUnitRaw: WeightUnit.kg.rawValue,
                    reps: 0, durationSec: seconds, distanceM: nil)
        case .distance(let meters):
            Columns(modeRaw: TrackingMode.distance.rawValue,
                    weightValue: 0, weightUnitRaw: WeightUnit.kg.rawValue,
                    reps: 0, durationSec: nil, distanceM: meters)
        }
    }

    /// 認不得的 `modeRaw`（舊版寫的、或未來版本寫回來的）一律當 `.weightReps`——
    /// 那是既有資料的形狀，也是唯一不會憑空生出數字的退路。
    static func decode(
        modeRaw: String, weightValue: Double, weightUnitRaw: String,
        reps: Int, durationSec: Int?, distanceM: Double?
    ) -> SetMeasurement {
        let weight = Weight(value: weightValue, unit: WeightUnit(rawValue: weightUnitRaw) ?? .kg)
        switch TrackingMode(rawValue: modeRaw) {
        case .bodyweightPlus: return .bodyweightPlus(added: weight, reps: reps)
        case .reps: return .reps(reps)
        case .duration: return .duration(seconds: durationSec ?? 0)
        case .distance: return .distance(meters: distanceM ?? 0)
        case .weightReps, nil: return .weightReps(weight: weight, reps: reps)
        }
    }
}
