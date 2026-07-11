import Foundation
import Testing

@testable import SharedKernel

struct AppEnvironmentTests {
    @Test func resolvesDevFromInfoDictionary() {
        let env = AppEnvironment.resolve(infoDictionary: [
            "AppEnv": "dev",
            "APIBaseURL": "https://training-la-api-dev.wly.lol",
        ])
        #expect(env.name == .dev)
        #expect(env.apiBaseURL.absoluteString == "https://training-la-api-dev.wly.lol")
        #expect(env.badge == "dev · training-la-api-dev.wly.lol")
    }

    @Test func resolvesProd() {
        let env = AppEnvironment.resolve(infoDictionary: [
            "AppEnv": "prod",
            "APIBaseURL": "https://training-la-api.wly.lol",
        ])
        #expect(env.name == .prod)
        #expect(env.apiBaseURL.host() == "training-la-api.wly.lol")
    }

    @Test func fallsBackToUnknownWhenMissing() {
        let env = AppEnvironment.resolve(infoDictionary: [:])
        #expect(env.name == .unknown)
    }

    @Test func fallsBackToUnknownForBadValue() {
        let env = AppEnvironment.resolve(infoDictionary: ["AppEnv": "staging"])
        #expect(env.name == .unknown)
    }
}
