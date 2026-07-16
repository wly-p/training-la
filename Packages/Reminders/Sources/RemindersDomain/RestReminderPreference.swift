import Foundation

/// 休息結束提醒的偏好：四種手段各自獨立開關（Settings 的複選 toggles）。
/// - popup：前景 in-app 彈窗
/// - banner：通知列（背景/鎖屏唯一能觸及的管道）
/// - sound：聲音
/// - haptic：震動（前景可自控；背景隨通知，無法「只震不響」）
public struct RestReminderPreference: Equatable, Sendable {
    public var popup: Bool
    public var banner: Bool
    public var sound: Bool
    public var haptic: Bool

    public init(popup: Bool, banner: Bool, sound: Bool, haptic: Bool) {
        self.popup = popup
        self.banner = banner
        self.sound = sound
        self.haptic = haptic
    }

    /// 預設：彈窗＋通知列＋聲音開，震動關（前景背景都被涵蓋，貼近改版前行為）。
    public static let `default` = RestReminderPreference(popup: true, banner: true, sound: true, haptic: false)

    /// 背景是否有任何可投遞的提醒（都關 → 背景完全不提醒）。
    public var hasBackgroundDelivery: Bool { banner || sound }
}
