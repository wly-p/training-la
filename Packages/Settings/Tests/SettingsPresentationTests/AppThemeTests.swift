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

    /// 深色閘門：關著的時候，不管存的偏好是什麼（包含「跟隨系統」），根部一律拿到淺色。
    /// 「跟隨系統」是最容易漏的一條——它回 nil，手機開深色的人照樣會看到破版。
    /// 閘門打開後則原樣回傳使用者選的值。
    @Test func effectiveColorSchemeHonoursDarkGate() {
        for theme in AppTheme.allCases {
            if AppTheme.isSelectionEnabled {
                #expect(theme.effectiveColorScheme == theme.colorScheme)
            } else {
                #expect(theme.effectiveColorScheme == .light)
            }
        }
    }
}
