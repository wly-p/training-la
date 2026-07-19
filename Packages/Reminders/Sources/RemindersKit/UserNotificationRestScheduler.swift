import Foundation
import RemindersDomain
import SharedKernel
import UserNotifications

/// 背景「休息結束」本地通知：結束時間 + 一則時間觸發通知，App 進背景/被殺也能提醒。
///
/// 通知內容在 `scheduleRestEnd` 當下組好、交給系統，之後由系統決定何時投遞——完全在 SwiftUI 之外，
/// 沒有 `Environment(\.locale)` 可用。文字改用哪個語言，只能在排程當下明確讀一次目前設定的語言
/// （`languageStore`），用 `AppLanguage.localizedString` 解析（不能用 `Text`／`String(localized:locale:)`）。
public struct UserNotificationRestScheduler: RestNotificationScheduling {
    private let identifier = "training.rest.end"
    private let languageStore: any LanguagePreferenceStoring

    public init(languageStore: any LanguagePreferenceStoring) {
        self.languageStore = languageStore
    }

    public func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    public func scheduleRestEnd(at date: Date, withSound: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return } // 已過期就不排

        let language = languageStore.load() ?? .fallback
        let content = UNMutableNotificationContent()
        content.title = language.localizedString("reminders.restOver.title", bundle: .module)
        content.body = language.localizedString("reminders.restOver.body", bundle: .module)
        content.sound = withSound ? .default : nil

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    public func cancelRestEnd() async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
