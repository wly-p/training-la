import Foundation
import RemindersDomain
import SharedKernel
import Testing

@testable import SettingsPresentation

private final class InMemoryThemeStore: ThemeStoring {
    var saved: AppTheme
    init(initial: AppTheme) { saved = initial }
    func load() -> AppTheme { saved }
    func save(_ theme: AppTheme) { saved = theme }
}

/// 非 actor：`IconSwitching.currentIconName` 是同步 `{ get }`（對齊 `UIApplication` 的同步存取），
/// 這些測試都在 `@MainActor` 情境下跑，用一般 class 即可，不需要 actor 隔離。
private final class MockIconSwitcher: IconSwitching, @unchecked Sendable {
    private(set) var currentIconName: String?
    var shouldFail = false
    private(set) var setCallCount = 0

    init(initial: String? = nil) { currentIconName = initial }

    func setIcon(_ name: String?) async throws {
        setCallCount += 1
        if shouldFail { throw StubError.failure }
        currentIconName = name
    }
}

private enum StubError: Error { case failure }

private final class MockDataEraser: DataErasing, @unchecked Sendable {
    private(set) var eraseCallCount = 0
    var shouldFail = false

    func eraseAllData() async throws {
        eraseCallCount += 1
        if shouldFail { throw StubError.failure }
    }
}

private struct StubNotificationAuthorizationChecking: NotificationAuthorizationChecking {
    let status: NotificationAuthorizationStatus
    func currentStatus() async -> NotificationAuthorizationStatus { status }
}

private final class MockHistoryExporter: WorkoutHistoryExporting, @unchecked Sendable {
    var jsonURL: URL = URL(fileURLWithPath: "/tmp/history.json")
    var csvURL: URL = URL(fileURLWithPath: "/tmp/history.csv")
    var shouldFail = false
    private(set) var exportJSONCallCount = 0
    private(set) var exportCSVCallCount = 0

    func exportJSON() async throws -> URL {
        exportJSONCallCount += 1
        if shouldFail { throw StubError.failure }
        return jsonURL
    }

    func exportCSV() async throws -> URL {
        exportCSVCallCount += 1
        if shouldFail { throw StubError.failure }
        return csvURL
    }
}

@MainActor
private func makeViewModel(
    theme: AppTheme = .system,
    iconSwitcher: MockIconSwitcher = MockIconSwitcher(),
    notificationAuthorization: any NotificationAuthorizationChecking = NoopNotificationAuthorizationChecking(),
    languageStore: any LanguagePreferenceStoring = InMemoryLanguageStore(),
    systemPreferredLanguages: [String] = [],
    dataEraser: MockDataEraser = MockDataEraser(),
    historyExporter: any WorkoutHistoryExporting = NoopWorkoutHistoryExporting(),
    onErased: @escaping @MainActor () -> Void = {}
) -> SettingsViewModel {
    SettingsViewModel(
        store: InMemoryThemeStore(initial: theme),
        iconSwitcher: iconSwitcher,
        notificationAuthorization: notificationAuthorization,
        languageStore: languageStore,
        systemPreferredLanguages: systemPreferredLanguages,
        dataEraser: dataEraser,
        historyExporter: historyExporter,
        onErased: onErased
    )
}

@MainActor
struct SettingsViewModelTests {
    @Test func loadsInitialThemeFromStore() {
        let store = InMemoryThemeStore(initial: .dark)
        let vm = SettingsViewModel(store: store, iconSwitcher: MockIconSwitcher())
        #expect(vm.theme == .dark)
    }

    @Test func changingThemePersists() {
        let store = InMemoryThemeStore(initial: .system)
        let vm = SettingsViewModel(store: store, iconSwitcher: MockIconSwitcher())

        vm.theme = .light

        #expect(vm.theme == .light)
        #expect(store.saved == .light)
    }

    @Test func colorSchemeMapping() {
        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
    }

    @Test func loadsInitialIconFromSwitcher() {
        let switcher = MockIconSwitcher(initial: "AppIcon-Checkmark")
        let vm = makeViewModel(iconSwitcher: switcher)
        #expect(vm.icon == .checkmark)
    }

    @Test func loadsDefaultIconWhenSwitcherHasNoAlternate() {
        let vm = makeViewModel(iconSwitcher: MockIconSwitcher(initial: nil))
        #expect(vm.icon == .default)
    }

    @Test func changingIconCallsSwitcher() async throws {
        let switcher = MockIconSwitcher()
        let vm = makeViewModel(iconSwitcher: switcher)

        vm.icon = .barbellPlate
        try await Task.sleep(nanoseconds: 20_000_000)

        #expect(switcher.currentIconName == "AppIcon-BarbellPlate")
    }

    @Test func settingSameIconDoesNotCallSwitcherAgain() async throws {
        let switcher = MockIconSwitcher(initial: nil)
        let vm = makeViewModel(iconSwitcher: switcher)

        vm.icon = .default
        try await Task.sleep(nanoseconds: 20_000_000)

        #expect(switcher.setCallCount == 0)
    }

    @Test func eraseAllDataWipesAndTriggersReset() async {
        let eraser = MockDataEraser()
        var resetCount = 0
        let vm = makeViewModel(dataEraser: eraser, onErased: { resetCount += 1 })

        await vm.eraseAllData()

        #expect(eraser.eraseCallCount == 1)
        #expect(resetCount == 1)
        #expect(vm.isErasing == false)
        #expect(vm.eraseFailed == false)
    }

    @Test func eraseAllDataFailureSurfacesErrorAndSkipsReset() async {
        let eraser = MockDataEraser()
        eraser.shouldFail = true
        var resetCount = 0
        let vm = makeViewModel(dataEraser: eraser, onErased: { resetCount += 1 })

        await vm.eraseAllData()

        #expect(eraser.eraseCallCount == 1)
        #expect(resetCount == 0)          // 失敗不重建畫面
        #expect(vm.isErasing == false)
        #expect(vm.eraseFailed == true)   // 綁 UI 錯誤 alert
    }

    @Test func firstLaunchSeedsLanguageFromSystemAndPersists() {
        // store 為空（第一次啟動）→ 由系統偏好決定，並 seed 回 store
        let store = InMemoryLanguageStore()
        let vm = makeViewModel(languageStore: store, systemPreferredLanguages: ["zh-Hant-TW", "en-US"])
        #expect(vm.language == .zhHant)
        #expect(store.load() == .zhHant) // 已 seed → 之後以設定為主
    }

    @Test func storedLanguageWinsOverSystem() {
        let store = InMemoryLanguageStore(.zhHant)
        let vm = makeViewModel(languageStore: store, systemPreferredLanguages: ["en-US"])
        #expect(vm.language == .zhHant)
    }

    @Test func firstLaunchPicksEnglishFromSystem() {
        let store = InMemoryLanguageStore()
        let vm = makeViewModel(languageStore: store, systemPreferredLanguages: ["en-US"])
        #expect(vm.language == .en)
        #expect(store.load() == .en)
    }

    @Test func changingLanguagePersists() {
        let store = InMemoryLanguageStore(.zhHant)
        let vm = makeViewModel(languageStore: store)
        vm.language = .zhHant
        #expect(store.load() == .zhHant)
    }

    @Test func loadsInitialRestReminderFromStore() {
        let pref = RestReminderPreference(popup: false, sound: false, backgroundNotification: true)
        let vm = SettingsViewModel(
            store: InMemoryThemeStore(initial: .system),
            iconSwitcher: MockIconSwitcher(),
            restReminderStore: InMemoryRestReminderPreferenceStore(pref)
        )
        #expect(vm.restReminder == pref)
    }

    @Test func changingRestReminderPersists() {
        let store = InMemoryRestReminderPreferenceStore(.default)
        let vm = SettingsViewModel(
            store: InMemoryThemeStore(initial: .system),
            iconSwitcher: MockIconSwitcher(),
            restReminderStore: store
        )

        vm.restReminder.sound = false
        vm.restReminder.backgroundNotification = false

        #expect(store.load().sound == false)
        #expect(store.load().backgroundNotification == false)
    }

    /// 開關不能說謊：系統實際拒絕了授權，`notificationAuthorizationDenied` 要反映出來，
    /// 不管偏好本身還顯示開著。
    @Test func refreshNotificationAuthorizationReflectsDeniedStatus() async {
        let vm = makeViewModel(notificationAuthorization: StubNotificationAuthorizationChecking(status: .denied))
        #expect(vm.notificationAuthorizationDenied == false) // 還沒查之前預設 false

        await vm.refreshNotificationAuthorization()

        #expect(vm.notificationAuthorizationDenied == true)
    }

    @Test func refreshNotificationAuthorizationReflectsAuthorizedStatus() async {
        let vm = makeViewModel(notificationAuthorization: StubNotificationAuthorizationChecking(status: .authorized))

        await vm.refreshNotificationAuthorization()

        #expect(vm.notificationAuthorizationDenied == false)
    }

    @Test func exportJSONSucceedsSetsExportedFile() async {
        let exporter = MockHistoryExporter()
        let vm = makeViewModel(historyExporter: exporter)

        await vm.exportJSON()

        #expect(exporter.exportJSONCallCount == 1)
        #expect(vm.exportedFile?.url == exporter.jsonURL)
        #expect(vm.isExporting == false)
        #expect(vm.exportFailed == false)
    }

    @Test func exportCSVSucceedsSetsExportedFile() async {
        let exporter = MockHistoryExporter()
        let vm = makeViewModel(historyExporter: exporter)

        await vm.exportCSV()

        #expect(exporter.exportCSVCallCount == 1)
        #expect(vm.exportedFile?.url == exporter.csvURL)
    }

    @Test func exportFailureSurfacesErrorAndClearsExportingFlag() async {
        let exporter = MockHistoryExporter()
        exporter.shouldFail = true
        let vm = makeViewModel(historyExporter: exporter)

        await vm.exportJSON()

        #expect(vm.exportFailed == true)
        #expect(vm.exportedFile == nil)
        #expect(vm.isExporting == false)
    }
}
