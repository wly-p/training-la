import SwiftUI

/// App 外觀主題。`system` 代表跟隨系統（preferredColorScheme(nil)）。
public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    /// String Catalog 的 key（繁中值見 `Localizable.xcstrings`）；View 用 `localText(_:)` 套 `bundle: .module`。
    public var displayName: LocalizedStringKey {
        switch self {
        case .system: "settings.theme.system"
        case .light: "settings.theme.light"
        case .dark: "settings.theme.dark"
        }
    }

    /// 套到根部的 `.preferredColorScheme`；system 回 nil＝交給系統。
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    // MARK: - 深色閘門

    /// 主題切換是否開放給使用者。**目前關著**：整個 App 鎖在淺色。
    ///
    /// 這不是 workaround，是閘門——色票（`DesignTokens`）的 dark 值目前只是 light 的複製，
    /// 深色下 App 自己畫的底不變、系統元件（alert、選單、鍵盤、Charts 座標軸）卻會翻成深色，
    /// 結果是白字壓在奶油色底上。比不提供深色更糟，而且「跟隨系統」也會踩到
    /// （手機開深色模式的人第一次啟動就中）。
    ///
    /// 深色色階（C6a）逐畫面驗證完之後把這個改成 `true` 即可：設定頁的主題列會回來、
    /// 根部改回吃使用者選的值，已存的偏好原封不動（鎖的期間不會去改寫它）。
    /// `project.yml` 的 `UIUserInterfaceStyle: Light` 是同一道閘門的另一半
    /// （管啟動畫面與 SwiftUI 接手之前的那一段），要一起拿掉。
    public static let isSelectionEnabled = false

    /// 根部實際該套的外觀：閘門關著時一律淺色，不管存的偏好是什麼。
    public var effectiveColorScheme: ColorScheme? {
        Self.isSelectionEnabled ? colorScheme : .light
    }
}
