import Foundation
import SharedKernel
import SwiftUI

/// 本 package 的本地化入口（自帶 String Catalog，`bundle: .module`）。見 Settings 同名檔說明。
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
    /// ViewModel 產「延後解析」的本地化錯誤字串，由 View 依 Environment locale 顯示。
    static func history(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}
