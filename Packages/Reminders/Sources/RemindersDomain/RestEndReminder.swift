import Foundation

/// 依「偏好 × App 狀態」把休息結束提醒 fan-out 到各手段的 dispatcher。純邏輯、無平台依賴。
///
/// 分工（見設計討論）：
/// - `schedule`：排程當下就把背景計畫烤進一則本地通知（背景到點 App 不會執行 code）。
///   「背景通知」開才排；那則通知是否帶聲音跟隨 sound 偏好。關 → 背景不排（清掉殘留）。
/// - `deliverForeground`：前景倒數歸零時播聲音（依偏好；系統音自帶震動，不另設開關）。
///   前景時那則系統通知不會被投遞——這是 iOS 的**預設**行為（沒有實作
///   `UNUserNotificationCenterDelegate` 時，前景收到的通知一律不呈現），
///   所以不會「in-app 播一次＋通知又響一次」。專案裡並沒有那個 delegate；
///   哪天要讓通知在前景也顯示橫幅，才需要自己實作它並在那裡做壓制。
public struct RestEndReminder: RestEndReminding {
    private let notifications: any RestNotificationScheduling
    private let sound: any ReminderSoundPlaying
    private let store: any RestReminderPreferenceStoring

    public init(
        notifications: any RestNotificationScheduling,
        sound: any ReminderSoundPlaying,
        store: any RestReminderPreferenceStoring
    ) {
        self.notifications = notifications
        self.sound = sound
        self.store = store
    }

    public var preference: RestReminderPreference { store.load() }

    public func schedule(at endDate: Date) async {
        let pref = store.load()
        // 背景通知＝單一開關：關掉就完全不排（並清掉殘留）；開著才排，聲音跟隨 sound 偏好。
        guard pref.backgroundNotification else {
            await notifications.cancelRestEnd()
            return
        }
        await notifications.requestAuthorization()
        await notifications.scheduleRestEnd(at: endDate, withSound: pref.sound)
    }

    public func cancel() async {
        await notifications.cancelRestEnd()
    }

    public func deliverForeground() async {
        let pref = store.load()
        if pref.sound { await sound.play() }
    }
}
