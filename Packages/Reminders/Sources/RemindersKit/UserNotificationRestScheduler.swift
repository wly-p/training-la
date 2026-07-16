import Foundation
import RemindersDomain
import UserNotifications

/// 背景「休息結束」本地通知：結束時間 + 一則時間觸發通知，App 進背景/被殺也能提醒。
public struct UserNotificationRestScheduler: RestNotificationScheduling {
    private let identifier = "training.rest.end"

    public init() {}

    public func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    public func scheduleRestEnd(at date: Date, withSound: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return } // 已過期就不排

        let content = UNMutableNotificationContent()
        content.title = "休息結束"
        content.body = "休息時間到了，準備下一組。"
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
