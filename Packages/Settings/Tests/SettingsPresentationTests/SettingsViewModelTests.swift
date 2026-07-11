import Testing

@testable import SettingsPresentation

private final class InMemoryThemeStore: ThemeStoring {
    var saved: AppTheme
    init(initial: AppTheme) { saved = initial }
    func load() -> AppTheme { saved }
    func save(_ theme: AppTheme) { saved = theme }
}

@MainActor
struct SettingsViewModelTests {
    @Test func loadsInitialThemeFromStore() {
        let store = InMemoryThemeStore(initial: .dark)
        let vm = SettingsViewModel(store: store)
        #expect(vm.theme == .dark)
    }

    @Test func changingThemePersists() {
        let store = InMemoryThemeStore(initial: .system)
        let vm = SettingsViewModel(store: store)

        vm.theme = .light

        #expect(vm.theme == .light)
        #expect(store.saved == .light)
    }

    @Test func colorSchemeMapping() {
        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
    }
}
