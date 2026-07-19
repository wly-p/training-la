import Foundation
import SwiftUI

/// 本 package 的本地化入口（自帶 String Catalog，`bundle: .module`）。見 Settings 同名檔說明。
func localText(_ key: LocalizedStringKey) -> Text {
    Text(key, bundle: .module)
}

extension LocalizedStringResource {
    /// ViewModel 產「延後解析」的本地化錯誤字串，由 View 依 Environment locale 顯示。
    static func plan(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}
