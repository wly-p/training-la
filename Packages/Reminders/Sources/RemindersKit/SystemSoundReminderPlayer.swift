import AudioToolbox
import Foundation
import RemindersDomain

/// 前景提示音：用系統音效播放。系統音效尊重響鈴/靜音開關（靜音時不響），符合「預設尊重靜音」。
public struct SystemSoundReminderPlayer: ReminderSoundPlaying {
    /// 1013＝系統內建的短提示音；之後要換自訂音檔再改這裡即可。
    private let soundID: SystemSoundID

    public init(soundID: SystemSoundID = 1013) {
        self.soundID = soundID
    }

    public func play() async {
        AudioServicesPlaySystemSound(soundID)
    }
}
