import RemindersDomain
import UserNotifications

/// `UNUserNotificationCenter.notificationSettings()` 的實作：讀系統目前實際允不允許通知，
/// 給 Settings 判斷「背景通知」開關是否已經失效（使用者拒絕過、但偏好仍顯示開著）。
public struct UserNotificationAuthorizationChecker: NotificationAuthorizationChecking {
    public init() {}

    public func currentStatus() async -> NotificationAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
}
