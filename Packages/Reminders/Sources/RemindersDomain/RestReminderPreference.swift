import Foundation

/// 休息結束提醒的偏好。
///
/// 前景（App 開著）可獨立控制：
/// - popup：in-app 彈窗
/// - sound：聲音（背景通知是否帶聲音也跟隨它）
///
/// 背景只有一則本地通知、兩個旋鈕（排不排、有無聲音）——iOS 做不到「只出聲不顯示」，
/// 所以背景收斂成單一開關：
/// - backgroundNotification：背景/鎖屏要不要通知；關掉則背景完全不提醒
///
/// 沒有獨立的震動設定：實測有聲音就伴隨震動（系統行為），拆不開，設定只會騙人。
public struct RestReminderPreference: Equatable, Sendable {
    public var popup: Bool
    public var sound: Bool
    public var backgroundNotification: Bool

    public init(popup: Bool, sound: Bool, backgroundNotification: Bool) {
        self.popup = popup
        self.sound = sound
        self.backgroundNotification = backgroundNotification
    }

    /// 預設：全開（前景背景都被涵蓋，貼近改版前行為）。
    public static let `default` = RestReminderPreference(
        popup: true, sound: true, backgroundNotification: true
    )
}
