import Foundation

// MARK: - Training 依賴的對外 port

/// 「休息結束提醒」的對外介面：休息倒數只呼叫這個，不知道底下有哪些手段。
/// 背景手段在 `schedule(at:)` 當下就烤進通知（背景到點 App 不會被喚醒執行）；
/// 前景手段（聲音）在倒數於前景歸零時由 `deliverForeground()` 觸發；
/// 彈窗屬前景 UI，由 View 讀 `preference.popup` 決定，不在此觸發。
public protocol RestEndReminding: Sendable {
    var preference: RestReminderPreference { get }
    /// 排定/重排背景通知計畫（依偏好；背景通知關則清掉殘留）。
    func schedule(at endDate: Date) async
    /// 取消尚未觸發的背景通知。
    func cancel() async
    /// 前景倒數歸零時播聲音（依偏好；系統音自帶震動）。
    func deliverForeground() async
    /// 提前請求背景通知授權（訓練開始時呼叫），避免第一次休息才彈系統彈窗。
    /// 偏好關閉時不問（沒有排通知的打算）。冪等，可重複呼叫。
    func prepareNotificationAuthorization() async
}

extension RestEndReminding {
    public func prepareNotificationAuthorization() async {}
}

// MARK: - 各手段的 channel port（可分別注入、替換；未來 Apple Watch＝換一組實作）

/// 背景本地通知：通知列＋（可選）聲音，一則搞定。
public protocol RestNotificationScheduling: Sendable {
    /// 首次使用請求通知權限（幕等）。
    func requestAuthorization() async
    /// 在 `date` 排「休息結束」通知（同 id 取代舊的）；`withSound` 決定是否帶提示音。過去時間不排。
    func scheduleRestEnd(at date: Date, withSound: Bool) async
    /// 取消尚未觸發的通知。
    func cancelRestEnd() async
}

/// 前景聲音。
public protocol ReminderSoundPlaying: Sendable {
    func play() async
}

// MARK: - 系統通知授權狀態（讀，不是「偏好」，是「系統實際允不允許」）

/// 抽成專案自己的型別，讓 domain 不用 import `UserNotifications`。
public enum NotificationAuthorizationStatus: Sendable {
    case notDetermined
    case authorized
    case denied
}

/// 讀取目前的系統通知授權狀態，給 Settings 判斷「背景通知」開關是否已經失效
/// （使用者拒絕過、但偏好仍顯示開著）用。
public protocol NotificationAuthorizationChecking: Sendable {
    func currentStatus() async -> NotificationAuthorizationStatus
}

public struct NoopNotificationAuthorizationChecking: NotificationAuthorizationChecking {
    public init() {}
    public func currentStatus() async -> NotificationAuthorizationStatus { .notDetermined }
}

// MARK: - 偏好持久化

public protocol RestReminderPreferenceStoring: Sendable {
    func load() -> RestReminderPreference
    func save(_ preference: RestReminderPreference)
}

// MARK: - 測試 / Preview 用 Noop

public struct NoopRestNotificationScheduling: RestNotificationScheduling {
    public init() {}
    public func requestAuthorization() async {}
    public func scheduleRestEnd(at date: Date, withSound: Bool) async {}
    public func cancelRestEnd() async {}
}

public struct NoopRestEndReminding: RestEndReminding {
    public var preference: RestReminderPreference
    public init(preference: RestReminderPreference = .default) { self.preference = preference }
    public func schedule(at endDate: Date) async {}
    public func cancel() async {}
    public func deliverForeground() async {}
}

public struct NoopReminderSoundPlaying: ReminderSoundPlaying {
    public init() {}
    public func play() async {}
}

/// 記憶體偏好儲存（測試/UITest 用；預設 `.default`）。
public final class InMemoryRestReminderPreferenceStore: RestReminderPreferenceStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var value: RestReminderPreference

    public init(_ initial: RestReminderPreference = .default) { value = initial }

    public func load() -> RestReminderPreference {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    public func save(_ preference: RestReminderPreference) {
        lock.lock(); defer { lock.unlock() }
        value = preference
    }
}
