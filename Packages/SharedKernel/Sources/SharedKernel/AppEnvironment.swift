import Foundation

/// 執行環境（由 build configuration 經 Info.plist 決定）。
public enum AppEnvironmentName: String, Sendable, Equatable, CaseIterable {
    case dev
    case prod
    /// Info.plist 沒帶或無法辨識時的保底值。
    case unknown
}

public struct AppEnvironment: Sendable, Equatable {
    public let name: AppEnvironmentName
    public let apiBaseURL: URL

    public init(name: AppEnvironmentName, apiBaseURL: URL) {
        self.name = name
        self.apiBaseURL = apiBaseURL
    }

    /// 從 Info.plist 解析（`AppEnv`、`APIBaseURL` 兩個鍵由 xcconfig 注入）。
    /// 純函式、不碰 Bundle，方便測試——App 傳 `Bundle.main.infoDictionary` 進來即可。
    public static func resolve(infoDictionary: [String: Any]) -> AppEnvironment {
        let name = (infoDictionary["AppEnv"] as? String)
            .flatMap(AppEnvironmentName.init(rawValue:)) ?? .unknown
        let url = (infoDictionary["APIBaseURL"] as? String)
            .flatMap(URL.init(string:)) ?? URL(string: "https://invalid.local")!
        return AppEnvironment(name: name, apiBaseURL: url)
    }

    /// 給環境小標用："dev · training-la-api-dev.wly.lol"
    public var badge: String {
        "\(name.rawValue) · \(apiBaseURL.host() ?? apiBaseURL.absoluteString)"
    }
}
