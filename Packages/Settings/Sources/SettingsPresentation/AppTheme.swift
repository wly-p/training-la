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
}
