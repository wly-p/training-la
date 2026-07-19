import Foundation
import SwiftUI

/// 這個 package 的本地化入口，統一走自帶 String Catalog（`Localizable.xcstrings`，`bundle: .module`）。
/// 見 Settings 的同名檔說明：SwiftUI 多數控制項不吃 `bundle:`，故 View 一律用 `localText(_:)`。
func localText(_ key: LocalizedStringKey) -> Text {
    Text(key, bundle: .module)
}

extension LocalizedStringResource {
    /// 給 ViewModel 產「延後解析」的本地化錯誤字串用：綁定本 package 的 bundle，
    /// 由 View 的 `Text(_:)` 依 Environment 的 `\.locale` 解析（切語言即時更新，且吃 app 覆寫的語言而非系統）。
    static func training(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}
