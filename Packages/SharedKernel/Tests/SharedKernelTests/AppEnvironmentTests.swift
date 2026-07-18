import Testing

@testable import SharedKernel

struct AppEnvironmentTests {
    @Test func resolvesDevFromInfoDictionary() {
        #expect(AppEnvironment.resolve(infoDictionary: ["AppEnv": "dev"]).name == .dev)
    }

    @Test func resolvesProd() {
        #expect(AppEnvironment.resolve(infoDictionary: ["AppEnv": "prod"]).name == .prod)
    }

    @Test func fallsBackToUnknownWhenMissing() {
        #expect(AppEnvironment.resolve(infoDictionary: [:]).name == .unknown)
    }

    @Test func fallsBackToUnknownForBadValue() {
        #expect(AppEnvironment.resolve(infoDictionary: ["AppEnv": "staging"]).name == .unknown)
    }
}
