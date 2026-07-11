/// 執行環境（由 build configuration 經 Info.plist 的 `AppEnv` 決定）。
///
/// v0 是單機版、不連任何 API，所以這裡**不含 host / apiBaseURL**。
/// 之後接同步（v1）時，API base URL 要以**注入變數**餵入（gitignored xcconfig 或 build 時環境變數），
/// committed 的程式碼/專案檔只留 `$(API_HOST)` 佔位符，真正的值從外部注入；
/// app 一律只讀本型別這個單一注入點，Swift 永不寫死 URL。
public enum AppEnvironmentName: String, Sendable, Equatable, CaseIterable {
    case dev
    case prod
    /// Info.plist 沒帶或無法辨識時的保底值。
    case unknown
}

public struct AppEnvironment: Sendable, Equatable {
    public let name: AppEnvironmentName

    public init(name: AppEnvironmentName) {
        self.name = name
    }

    /// 從 Info.plist 的 `AppEnv` 解析（由 build config 注入）。純函式、不碰 Bundle，方便測試。
    public static func resolve(infoDictionary: [String: Any]) -> AppEnvironment {
        let name = (infoDictionary["AppEnv"] as? String)
            .flatMap(AppEnvironmentName.init(rawValue:)) ?? .unknown
        return AppEnvironment(name: name)
    }

    /// 設定頁的環境小標（例："dev"）。
    public var badge: String { name.rawValue }
}
