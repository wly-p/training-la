import Foundation
import RemindersDomain

#if canImport(UIKit)
import UIKit

/// 前景震動：休息結束用一次成功類型的 haptic。僅 iOS（UIKit）有；其他平台為 no-op。
public struct HapticReminderPlayer: ReminderHapticPlaying {
    public init() {}

    public func play() async {
        await MainActor.run {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}
#else

/// 非 UIKit 平台（如 macOS 跑 swift test）：no-op，讓 package 仍能編譯。
public struct HapticReminderPlayer: ReminderHapticPlaying {
    public init() {}
    public func play() async {}
}
#endif
