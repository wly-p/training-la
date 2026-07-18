import Foundation

/// 語言偏好的持久化。跟 ``ThemeStoring`` 同 pattern：單一偏好，protocol 化方便注入 mock。
/// `load()` 回 optional：`nil` ＝使用者從未選過 → 第一次啟動時走系統偵測（見 ``LanguageResolver``）。
public protocol LanguagePreferenceStoring {
    func load() -> AppLanguage?
    func save(_ language: AppLanguage)
}

/// UserDefaults 實作（單一偏好，不值得為它拉一整套 repository）。
public struct UserDefaultsLanguageStore: LanguagePreferenceStoring {
    private let defaults: UserDefaults
    private let key = "settings.appLanguage"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppLanguage? {
        defaults.string(forKey: key).flatMap(AppLanguage.init(rawValue:))
    }

    public func save(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: key)
    }
}

/// 測試 / UI 測試用：不落地，每次啟動乾淨。
public final class InMemoryLanguageStore: LanguagePreferenceStoring, @unchecked Sendable {
    private var value: AppLanguage?
    public init(_ initial: AppLanguage? = nil) { value = initial }
    public func load() -> AppLanguage? { value }
    public func save(_ language: AppLanguage) { value = language }
}
