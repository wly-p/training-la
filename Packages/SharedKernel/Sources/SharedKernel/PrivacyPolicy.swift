import Foundation

/// 隱私政策頁的網址（讀 Info.plist 的 `PrivacyPolicyURL`，由 `Config.xcconfig` 的
/// `PRIVACY_POLICY_URL` 注入）。純函式、不碰 Bundle，方便測試。
///
/// App **不打包政策頁的副本**：政策可以在不發版的情況下更新，bundle 裡的副本會直接變成錯的內容，
/// 而政策與實際行為不符是可以導致下架的。所以線上那份就是唯一來源，離線點開＝Safari 的錯誤頁。
///
/// 網址走注入變數而不是寫在 Swift 裡，是 ``AppEnvironment`` 註解裡就定下的規矩：
/// committed 的程式碼／專案檔只留 `$()` 佔位符，真正的值從外部注入。
public enum PrivacyPolicy {
    /// - Returns: plist 沒帶、空字串或不是合法網址時回 nil（呼叫端據此不顯示入口，
    ///   而不是給使用者一個點了沒反應的列）。
    public static func baseURL(infoDictionary: [String: Any]) -> URL? {
        guard let raw = (infoDictionary["PrivacyPolicyURL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty,
            let url = URL(string: raw),
            url.scheme != nil, url.host != nil
        else { return nil }
        return url
    }

    /// 依 **App 語言**補上 fragment（例：`…/privacy-policy#zh-Hant`）。
    ///
    /// 語言只能由 URL 帶：伺服器只看得到 `Accept-Language`＝**裝置語系**，而 app 語言可以跟它不同
    /// （見 ``AppLanguage``），所以內容協商在這裡是錯的訊號。頁面那端用 `/^zh/` 前綴比對 hash，
    /// 因此這裡直接送 `rawValue` 即可，兩邊不必各養一份語言代碼對照表。
    ///
    /// 用 `URLComponents.fragment` 而不是字串相接：後者遇到 base 本身已帶 fragment 就會疊出
    /// 兩個 `#`，而 `URL(string:)` 對那種字串是回 nil 的。
    public static func localizedURL(base: URL, language: AppLanguage) -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return base }
        components.fragment = language.rawValue
        return components.url ?? base
    }
}
