import Foundation

/// 依「偏好 × App 狀態」把休息結束提醒 fan-out 到各手段的 dispatcher。純邏輯、無平台依賴。
///
/// 分工（見設計討論）：
/// - `schedule`：排程當下就把背景計畫烤進一則本地通知（背景到點 App 不會執行 code）。
///   通知列開才排通知；聲音開則那則通知帶 sound。兩者皆關 → 背景不排（清掉殘留）。
/// - `deliverForeground`：前景倒數歸零時跑聲音／震動（依偏好）。前景時那則系統通知
///   由 App 的通知 delegate 壓掉，避免「in-app 播一次＋通知又響一次」。
public struct RestEndReminder: RestEndReminding {
    private let notifications: any RestNotificationScheduling
    private let sound: any ReminderSoundPlaying
    private let haptic: any ReminderHapticPlaying
    private let store: any RestReminderPreferenceStoring

    public init(
        notifications: any RestNotificationScheduling,
        sound: any ReminderSoundPlaying,
        haptic: any ReminderHapticPlaying,
        store: any RestReminderPreferenceStoring
    ) {
        self.notifications = notifications
        self.sound = sound
        self.haptic = haptic
        self.store = store
    }

    public var preference: RestReminderPreference { store.load() }

    public func schedule(at endDate: Date) async {
        let pref = store.load()
        // 背景只能靠一則本地通知投遞。通知列「或」聲音任一開就排（聲音依偏好帶上）；
        // 兩者皆關才完全不排。註：iOS 一旦排通知，背景就會顯示橫幅——「聲音開但通知列關」
        // 仍會出現橫幅，這是本地通知無法「只出聲不顯示」的限制。
        guard pref.hasBackgroundDelivery else {
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
        if pref.haptic { await haptic.play() }
    }
}
