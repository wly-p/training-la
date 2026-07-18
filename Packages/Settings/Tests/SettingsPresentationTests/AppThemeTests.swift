import Testing

@testable import SettingsPresentation

struct AppThemeTests {
    @Test func idMatchesRawValue() {
        for theme in AppTheme.allCases {
            #expect(theme.id == theme.rawValue)
        }
    }

    @Test func displayNameMapsToCatalogKeys() {
        // displayName 現在回傳 String Catalog 的 key（繁中值見 Localizable.xcstrings）
        #expect(AppTheme.system.displayName == "settings.theme.system")
        #expect(AppTheme.light.displayName == "settings.theme.light")
        #expect(AppTheme.dark.displayName == "settings.theme.dark")
    }

    @Test func allCasesCoversThreeThemes() {
        #expect(AppTheme.allCases == [.system, .light, .dark])
    }
}
