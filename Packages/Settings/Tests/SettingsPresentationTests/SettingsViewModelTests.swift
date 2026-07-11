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

@MainActor
private func makeViewModel(
    theme: AppTheme = .system,
    iconSwitcher: MockIconSwitcher = MockIconSwitcher()
) -> SettingsViewModel {
    SettingsViewModel(store: InMemoryThemeStore(initial: theme), iconSwitcher: iconSwitcher)
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
}
