import Foundation

/// 主題偏好的持久化。抽成 protocol 讓 ViewModel 可注入 mock 測試。
/// 只在 @MainActor 的 ViewModel 內使用，不跨 actor，故不需 Sendable。
public protocol ThemeStoring {
    func load() -> AppTheme
    func save(_ theme: AppTheme)
}

/// UserDefaults 實作（單一偏好，不值得為它拉一整套 repository）。
public struct UserDefaultsThemeStore: ThemeStoring {
    private let defaults: UserDefaults
    private let key = "settings.appTheme"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppTheme {
        defaults.string(forKey: key).flatMap(AppTheme.init(rawValue:)) ?? .system
    }

    public func save(_ theme: AppTheme) {
        defaults.set(theme.rawValue, forKey: key)
    }
}
