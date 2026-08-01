import Foundation
import SharedKernel
import SwiftUI

/// 這個 package 的本地化入口，統一走自帶 String Catalog（`Localizable.xcstrings`，`bundle: .module`）。
/// 見 Settings 的同名檔說明：SwiftUI 多數控制項不吃 `bundle:`，故 View 一律用 `localText(_:)`。
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

extension LocalizedStringResource {
    /// 給 ViewModel 產「延後解析」的本地化錯誤字串用：綁定本 package 的 bundle，
    /// 由 View 的 `Text(_:)` 依 Environment 的 `\.locale` 解析（切語言即時更新，且吃 app 覆寫的語言而非系統）。
    static func training(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}
