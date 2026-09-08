import SwiftUI

/// 使用者偏好的重量顯示單位，從根部注入、整棵樹讀得到。
///
/// 沿用專案既有的注入慣例——語言就是這樣傳的（`App/RootView.swift` 的
/// `.environment(\.locale, settingsViewModel.language.locale)`），設定一改整個 App 立即反映。
///
/// ## 只影響顯示
///
/// 每筆紀錄仍存輸入當下的 `{value, unit}`。來回換算會侵蝕原值——使用者輸入 60kg，
/// 不該因為切了兩次單位就變成 59.99——所以換算只發生在要印出來的那一刻。
///
/// **聚合不走這裡。** 總量那類加總一律先換算成公斤再相加（見 `SessionTotals`），
/// 混單位相加的數字沒有意義。顯示單位只在最後把結果印出來時才套用。
///
/// ## 為什麼放這裡而不是 DesignSystem
///
/// 這是「presentation 的關注點，但需要 domain 型別」。DesignSystem 刻意是零依賴的
/// 純視覺層，讓它認識 kg/lb 等於把 domain 概念塞進設計系統。而 `WeightUnit` 本來就
/// 住在 SharedKernel，六個 Presentation package 也全都已經 import 它——放這裡不需要
/// 任何一邊新增依賴。代價是 SharedKernel 從此帶著 SwiftUI，接受。
extension EnvironmentValues {
    @Entry public var weightDisplayUnit: WeightUnit = .kg
}
