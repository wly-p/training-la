import Foundation
import Testing

@testable import SettingsPresentation

struct UserDefaultsThemeStoreTests {
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "UserDefaultsThemeStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func loadFallsBackToSystemWhenNothingStored() {
        let store = UserDefaultsThemeStore(defaults: makeIsolatedDefaults())
        #expect(store.load() == .system)
    }

    @Test func saveThenLoadRoundTrips() {
        let store = UserDefaultsThemeStore(defaults: makeIsolatedDefaults())

        store.save(.dark)

        #expect(store.load() == .dark)
    }

    @Test func loadFallsBackToSystemForCorruptedValue() {
        let defaults = makeIsolatedDefaults()
        defaults.set("not-a-theme", forKey: "settings.appTheme")
        let store = UserDefaultsThemeStore(defaults: defaults)

        #expect(store.load() == .system)
    }
}
