import SharedKernel
import Testing

struct AppVersionTests {
    @Test func formatsVersionWithBuild() {
        let s = AppVersion.displayString(infoDictionary: [
            "CFBundleShortVersionString": "1.2.0",
            "CFBundleVersion": "37",
        ])
        #expect(s == "1.2.0 (37)")
    }

    @Test func fallsBackToVersionOnlyWhenBuildMissing() {
        let s = AppVersion.displayString(infoDictionary: ["CFBundleShortVersionString": "1.2.0"])
        #expect(s == "1.2.0")
    }

    @Test func returnsNilWhenVersionMissing() {
        #expect(AppVersion.displayString(infoDictionary: [:]) == nil)
    }
}
