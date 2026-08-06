import Foundation
import SharedKernel
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

/// 同一份 String Catalog 的 plain String 版本，給拿不到 `Text` 的地方用
/// （元件的 `title:`／`message:` 參數、`String(format:)` 的 format、字串拼接、`??` 兜底）。
///
/// **不要用 `String(localized:)`**：它是立即求值、只認 process locale（＝手機語系），
/// 不吃我們注入的 `\.locale` environment，於是「手機語系 ≠ app 語言」時整片不跟著切。
/// `AppLanguage.localizedString` 明確開該語言的 lproj 子 bundle 查表，是唯一有效的作法。
///
/// 呼叫端在 View 裡加 `@Environment(\.locale) private var locale` 後傳進來。
func localString(_ key: String, _ locale: Locale) -> String {
    AppLanguage(locale: locale).localizedString(key, bundle: .module)
}
