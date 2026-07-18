import SharedKernel
import Testing

struct AppVersionTests {
    @Test func devShowsVersionWithBuild() {
        let s = AppVersion.displayString(infoDictionary: [
            "AppEnv": "dev",
            "CFBundleShortVersionString": "1.2.0",
            "CFBundleVersion": "37",
        ])
        #expect(s == "1.2.0 (37)")
    }

    @Test func prodHidesBuild() {
        let s = AppVersion.displayString(infoDictionary: [
            "AppEnv": "prod",
            "CFBundleShortVersionString": "1.2.0",
            "CFBundleVersion": "37",
        ])
        #expect(s == "1.2.0")
    }

    @Test func unknownEnvironmentShowsBuildLikeDev() {
        // AppEnv 沒帶＝環境不明，多給資訊比少給好（debug 用）
        let s = AppVersion.displayString(infoDictionary: [
            "CFBundleShortVersionString": "1.2.0",
            "CFBundleVersion": "37",
        ])
        #expect(s == "1.2.0 (37)")
    }

    @Test func fallsBackToVersionOnlyWhenBuildMissing() {
        let s = AppVersion.displayString(infoDictionary: [
            "AppEnv": "dev",
            "CFBundleShortVersionString": "1.2.0",
        ])
        #expect(s == "1.2.0")
    }

    @Test func returnsNilWhenVersionMissing() {
        #expect(AppVersion.displayString(infoDictionary: ["AppEnv": "dev"]) == nil)
    }
}
