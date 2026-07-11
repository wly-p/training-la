import Testing

@testable import SettingsPresentation

struct AppThemeTests {
    @Test func idMatchesRawValue() {
        for theme in AppTheme.allCases {
            #expect(theme.id == theme.rawValue)
        }
    }

    @Test func displayNameMapsCorrectly() {
        #expect(AppTheme.system.displayName == "跟隨系統")
        #expect(AppTheme.light.displayName == "淺色")
        #expect(AppTheme.dark.displayName == "深色")
    }

    @Test func allCasesCoversThreeThemes() {
        #expect(AppTheme.allCases == [.system, .light, .dark])
    }
}
