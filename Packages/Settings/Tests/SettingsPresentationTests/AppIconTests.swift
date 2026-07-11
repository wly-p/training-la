import Testing

@testable import SettingsPresentation

struct AppIconTests {
    @Test func defaultIconHasNoAssetName() {
        #expect(AppIcon.default == .sandArrow)
        #expect(AppIcon.default.assetName == nil)
    }

    @Test func everyNonDefaultCaseHasAnAssetNamePrefixedWithAppIcon() {
        for icon in AppIcon.allCases where icon != .default {
            #expect(icon.assetName?.hasPrefix("AppIcon-") == true)
        }
    }

    @Test func everyCaseHasANonEmptyDisplayNameAndPreviewImageName() {
        for icon in AppIcon.allCases {
            #expect(!icon.displayName.isEmpty)
            #expect(icon.previewImageName == "IconPreview-\(icon.rawValue)")
        }
    }

    @Test func initFromAssetNameRoundTrips() {
        for icon in AppIcon.allCases {
            #expect(AppIcon(assetName: icon.assetName) == icon)
        }
    }

    @Test func initFromUnknownAssetNameFallsBackToDefault() {
        #expect(AppIcon(assetName: "not-a-real-icon") == .default)
    }

    @Test func allCasesCoversEightIcons() {
        #expect(AppIcon.allCases.count == 8)
    }
}
