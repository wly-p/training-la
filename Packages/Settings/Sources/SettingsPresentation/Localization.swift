import SwiftUI

/// 這個 package 的本地化文字入口：統一走自帶的 String Catalog（`Localizable.xcstrings`，`bundle: .module`）。
///
/// 為什麼要 helper：SwiftUI 的 `Section` / `Picker` / `Toggle` / `Button` / `alert` / `navigationTitle`
/// 只吃 `LocalizedStringKey`、不吃 `bundle:` 參數，預設會去 `Bundle.main` 查表、找不到 package 自己的翻譯。
/// 只有 `Text` 有 `bundle:`，所以一律用這個 helper 包成 `Text(key, bundle: .module)` 再交給那些控制項的
/// label / header ViewBuilder。切語言時由 SwiftUI Environment 的 `\.locale` 驅動重繪，呼叫端不用改。
func localText(_ key: LocalizedStringKey) -> Text {
    Text(key, bundle: .module)
}
