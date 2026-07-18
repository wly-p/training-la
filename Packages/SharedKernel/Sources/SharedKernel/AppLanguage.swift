import Foundation

/// App 支援的語言。數量刻意少：新增語言＝加一個 case（rawValue 用 BCP-47 語言代碼）
/// ＋補該語言的 String Catalog 翻譯，其餘（resolver / store / Environment 注入）都不用動。
public enum AppLanguage: String, CaseIterable, Sendable, Identifiable {
    /// 繁體中文（目前唯一，也是 default）。
    case zhHant = "zh-Hant"

    public var id: String { rawValue }

    /// 沒有偏好、系統語言又不在支援清單時的保底語言。
    public static let fallback: AppLanguage = .zhHant

    /// 對應的 `Locale`，注入 SwiftUI Environment（`\.locale`）用。
    public var locale: Locale { Locale(identifier: rawValue) }

    /// 語言選單顯示用的母語名稱（例："繁體中文"）；之後做語言 Picker 時用。
    public var nativeName: String {
        switch self {
        case .zhHant: "繁體中文"
        }
    }
}

/// 決定 App 當前語言的純函式邏輯：不碰 Bundle / UserDefaults，方便測試。
/// 對齊 ``AppEnvironment/resolve(infoDictionary:)`` 的「pure resolve」風格。
public enum LanguageResolver {
    /// - Parameters:
    ///   - stored: 使用者在設定裡選過的語言；有值就直接用（**設定為主**）。
    ///   - systemPreferred: 系統偏好語言清單（`Locale.preferredLanguages`，BCP-47，
    ///     例 `["zh-Hant-TW", "en-US"]`）。
    /// - Returns: 規則——設定有值 → 用設定；否則（第一次開啟）逐一比對系統偏好，
    ///   命中支援清單就用，全部沒中 → ``AppLanguage/fallback``。
    public static func resolve(stored: AppLanguage?, systemPreferred: [String]) -> AppLanguage {
        if let stored { return stored }
        let supported = AppLanguage.allCases.map(\.rawValue)
        for id in systemPreferred {
            if let matched = match(languageID: id, supported: supported) {
                return AppLanguage(rawValue: matched) ?? .fallback
            }
        }
        return .fallback
    }

    /// 把單一系統語言代碼比對到支援清單，回傳命中的支援代碼（依 `supported` 順序取第一個）。
    /// 容忍地區／腳本後綴：`"zh-Hant-TW"` 命中 `"zh-Hant"`、`"en-US"` 命中 `"en"`。
    /// 抽成獨立純函式，讓比對邏輯不綁「目前只有幾個語言」也能完整測。
    static func match(languageID: String, supported: [String]) -> String? {
        supported.first { code in
            languageID == code || languageID.hasPrefix(code + "-")
        }
    }
}
