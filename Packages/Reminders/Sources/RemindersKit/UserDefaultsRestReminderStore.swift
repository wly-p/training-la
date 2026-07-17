import Foundation
import RemindersDomain

/// 休息提醒偏好的持久化（UserDefaults）。四個 bool 各存一個 key；缺值時回 `.default`。
public struct UserDefaultsRestReminderStore: RestReminderPreferenceStoring {
    // UserDefaults 執行緒安全但未標 Sendable；偏好讀寫可能在非 MainActor 發生，故明示安全。
    nonisolated(unsafe) private let defaults: UserDefaults
    private let prefix = "settings.restReminder."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> RestReminderPreference {
        let d = RestReminderPreference.default
        return RestReminderPreference(
            popup: bool("popup", default: d.popup),
            sound: bool("sound", default: d.sound),
            backgroundNotification: bool("backgroundNotification", default: d.backgroundNotification)
        )
    }

    public func save(_ preference: RestReminderPreference) {
        defaults.set(preference.popup, forKey: prefix + "popup")
        defaults.set(preference.sound, forKey: prefix + "sound")
        defaults.set(preference.backgroundNotification, forKey: prefix + "backgroundNotification")
    }

    private func bool(_ key: String, default fallback: Bool) -> Bool {
        defaults.object(forKey: prefix + key) as? Bool ?? fallback
    }
}
