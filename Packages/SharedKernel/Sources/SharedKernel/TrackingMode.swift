import Foundation

/// 一個動作用什麼量測它的表現。
///
/// 既有動作全部是 `.weightReps`（init 預設值），行為不變。
public enum TrackingMode: String, Codable, Sendable, CaseIterable {
    /// 重量 × 次數。槓鈴、啞鈴、機械——絕大多數動作。
    case weightReps
    /// 只有次數，沒有重量。引體向上、伏地挺身。
    case reps
    /// 撐了多久。棒式、死撐、農夫走路的計時版本。
    case duration
    /// 移動了多遠。跑步、划船機、滑步機。
    case distance
    /// 自體重再加負重。負重引體、負重雙槓。
    case bodyweightPlus
}

/// 一組實際做出來的量測值。
///
/// **刻意做成 enum 而不是一堆並排的 optional 欄位**：非法組合（例如「時間模式卻帶著重量」）
/// 在型別上就構不出來，而且之後每加一個新功能，編譯器都會逼呼叫端把每種模式講清楚。
/// 換成 `weight: Weight?` ＋ `durationSec: Int?` 並排的話，棒式那一組會在歷史頁
/// 悄悄顯示成「0 kg × 0 次」，不報錯，要等人看到才發現。
///
/// 同理**不要**為了方便加一個 `var weight: Weight?` 的存取子——那等於把這層保護退掉。
///
/// Data 層存的是扁平欄位（見 `SetMeasurementCoding`），這個 enum 只活在 Domain。
public enum SetMeasurement: Equatable, Sendable {
    case weightReps(weight: Weight, reps: Int)
    case reps(Int)
    case duration(seconds: Int)
    case distance(meters: Double)
    case bodyweightPlus(added: Weight, reps: Int)

    /// 對應的追蹤模式（Data 層存 raw 值、UI 分支用）。
    public var mode: TrackingMode {
        switch self {
        case .weightReps: .weightReps
        case .reps: .reps
        case .duration: .duration
        case .distance: .distance
        case .bodyweightPlus: .bodyweightPlus
        }
    }

    /// 訓練量（公斤 × 次數）。**只有帶重量的模式有值**，其餘回 nil。
    ///
    /// `bodyweightPlus` 只算加重的部分：全專案沒有「使用者體重」這個概念，
    /// 拿體重估算需要新的輸入欄位（＝需要 UI），在那之前少報比亂報好。
    public var volumeKilograms: Double? {
        switch self {
        case .weightReps(let weight, let reps): weight.kilograms * Double(reps)
        case .bodyweightPlus(let added, let reps): added.kilograms * Double(reps)
        case .reps, .duration, .distance: nil
        }
    }
}
