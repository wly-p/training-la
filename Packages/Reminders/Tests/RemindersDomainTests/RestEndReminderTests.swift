import Foundation
import Testing

@testable import RemindersDomain

private actor SpyNotifications: RestNotificationScheduling {
    private(set) var authCount = 0
    private(set) var scheduled: [(date: Date, sound: Bool)] = []
    private(set) var cancelCount = 0
    func requestAuthorization() async { authCount += 1 }
    func scheduleRestEnd(at date: Date, withSound: Bool) async { scheduled.append((date, withSound)) }
    func cancelRestEnd() async { cancelCount += 1 }
}

private actor SpyPlayer: ReminderSoundPlaying, ReminderHapticPlaying {
    private(set) var playCount = 0
    func play() async { playCount += 1 }
}

private func makeReminder(
    _ pref: RestReminderPreference,
    notifications: SpyNotifications = SpyNotifications(),
    sound: SpyPlayer = SpyPlayer(),
    haptic: SpyPlayer = SpyPlayer()
) -> RestEndReminder {
    RestEndReminder(
        notifications: notifications,
        sound: sound,
        haptic: haptic,
        store: InMemoryRestReminderPreferenceStore(pref)
    )
}

struct RestEndReminderTests {
    private let end = Date(timeIntervalSince1970: 2000)

    @Test func schedulesNotificationWithSoundWhenBannerAndSoundOn() async {
        let notifs = SpyNotifications()
        let reminder = makeReminder(.init(popup: true, banner: true, sound: true, haptic: false), notifications: notifs)

        await reminder.schedule(at: end)

        #expect(await notifs.authCount == 1)
        let scheduled = await notifs.scheduled
        #expect(scheduled.count == 1)
        #expect(scheduled.first?.date == end)
        #expect(scheduled.first?.sound == true)
    }

    @Test func schedulesSilentNotificationWhenBannerOnSoundOff() async {
        let notifs = SpyNotifications()
        let reminder = makeReminder(.init(popup: false, banner: true, sound: false, haptic: false), notifications: notifs)

        await reminder.schedule(at: end)

        #expect(await notifs.scheduled.first?.sound == false)
    }

    @Test func schedulesSoundNotificationWhenBannerOffButSoundOn() async {
        let notifs = SpyNotifications()
        // 通知列關但聲音開 → 背景仍要排通知（帶聲音），否則背景什麼提醒都收不到
        let reminder = makeReminder(.init(popup: true, banner: false, sound: true, haptic: false), notifications: notifs)

        await reminder.schedule(at: end)

        #expect(await notifs.scheduled.count == 1)
        #expect(await notifs.scheduled.first?.sound == true)
    }

    @Test func skipsNotificationAndClearsWhenBannerAndSoundOff() async {
        let notifs = SpyNotifications()
        // 通知列、聲音皆關 → 背景無可投遞，不排並清掉殘留
        let reminder = makeReminder(.init(popup: true, banner: false, sound: false, haptic: true), notifications: notifs)

        await reminder.schedule(at: end)

        #expect(await notifs.scheduled.isEmpty)
        #expect(await notifs.cancelCount == 1)
        #expect(await notifs.authCount == 0) // 不排就不請求權限
    }

    @Test func cancelForwardsToNotifications() async {
        let notifs = SpyNotifications()
        let reminder = makeReminder(.default, notifications: notifs)

        await reminder.cancel()

        #expect(await notifs.cancelCount == 1)
    }

    @Test func foregroundPlaysSoundAndHapticPerPreference() async {
        let sound = SpyPlayer()
        let haptic = SpyPlayer()
        let reminder = makeReminder(.init(popup: true, banner: true, sound: true, haptic: true),
                                    sound: sound, haptic: haptic)

        await reminder.deliverForeground()

        #expect(await sound.playCount == 1)
        #expect(await haptic.playCount == 1)
    }

    @Test func foregroundSkipsDisabledChannels() async {
        let sound = SpyPlayer()
        let haptic = SpyPlayer()
        // 只開聲音
        let reminder = makeReminder(.init(popup: true, banner: false, sound: true, haptic: false),
                                    sound: sound, haptic: haptic)

        await reminder.deliverForeground()

        #expect(await sound.playCount == 1)
        #expect(await haptic.playCount == 0)
    }

    @Test func preferenceReflectsStore() {
        let pref = RestReminderPreference(popup: false, banner: true, sound: false, haptic: true)
        let reminder = makeReminder(pref)
        #expect(reminder.preference == pref)
    }
}
