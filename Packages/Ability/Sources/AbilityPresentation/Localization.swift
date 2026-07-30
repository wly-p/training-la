import SwiftUI

/// 這個 package 的本地化文字入口：統一走自帶的 String Catalog（`Localizable.xcstrings`，`bundle: .module`）。
func localText(_ key: LocalizedStringKey) -> Text {
    Text(key, bundle: .module)
}
