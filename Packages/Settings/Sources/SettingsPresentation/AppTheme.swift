import SwiftUI

/// App 外觀主題。`system` 代表跟隨系統（preferredColorScheme(nil)）。
public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: "跟隨系統"
        case .light: "淺色"
        case .dark: "深色"
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
