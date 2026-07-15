import Foundation
import UserNotifications

/// 休息倒數的本地通知排程。抽成協定：ViewModel 依賴它、可注入假物件測試，
/// App 端注入真正打 UNUserNotificationCenter 的實作。
public protocol RestNotificationScheduling: Sendable {
    /// 首次使用時請求通知權限（已授權/已拒絕都是幕等，不會重複跳系統彈窗）。
    func requestAuthorization() async
    /// 在 `date` 排一則「休息結束」本地通知（同 id 會取代舊的）。過去時間則不排。
    func scheduleRestEnd(at date: Date) async
    /// 取消尚未觸發的「休息結束」通知（跳過休息/撤銷時用）。
    func cancelRestEnd() async
}

/// 測試與 Preview 用：什麼都不做。
public struct NoopRestNotificationScheduler: RestNotificationScheduling {
    public init() {}
    public func requestAuthorization() async {}
    public func scheduleRestEnd(at date: Date) async {}
    public func cancelRestEnd() async {}
}

/// 正式實作：用 `UNUserNotificationCenter` 排一則時間觸發的本地通知。
/// 倒數改用「結束時間 + 本地通知」而非背景執行 timer，App 進背景也不會停、時間到照樣提醒。
public struct UserNotificationRestScheduler: RestNotificationScheduling {
    private let identifier = "training.rest.end"

    public init() {}

    public func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    public func scheduleRestEnd(at date: Date) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return } // 已過期就不排

        let content = UNMutableNotificationContent()
        content.title = "休息結束"
        content.body = "休息時間到了，準備下一組。"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    public func cancelRestEnd() async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
