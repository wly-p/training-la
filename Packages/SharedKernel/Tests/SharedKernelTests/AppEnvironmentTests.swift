import Testing

@testable import SharedKernel

struct AppEnvironmentTests {
    @Test func resolvesDevFromInfoDictionary() {
        let env = AppEnvironment.resolve(infoDictionary: ["AppEnv": "dev"])
        #expect(env.name == .dev)
        #expect(env.badge == "dev")
    }

    @Test func resolvesProd() {
        let env = AppEnvironment.resolve(infoDictionary: ["AppEnv": "prod"])
        #expect(env.name == .prod)
        #expect(env.badge == "prod")
    }

    @Test func fallsBackToUnknownWhenMissing() {
        #expect(AppEnvironment.resolve(infoDictionary: [:]).name == .unknown)
    }

    @Test func fallsBackToUnknownForBadValue() {
        #expect(AppEnvironment.resolve(infoDictionary: ["AppEnv": "staging"]).name == .unknown)
    }
}
