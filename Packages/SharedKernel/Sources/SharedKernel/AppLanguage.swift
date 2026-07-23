import Foundation

/// App 支援的語言。數量刻意少：新增語言＝加一個 case（rawValue 用 BCP-47 語言代碼）
/// ＋補該語言的 String Catalog 翻譯，其餘（resolver / store / Environment 注入）都不用動。
public enum AppLanguage: String, CaseIterable, Sendable, Identifiable {
    /// 繁體中文（default）。
    case zhHant = "zh-Hant"
    /// English。
    case en = "en"

    public var id: String { rawValue }

    /// 沒有偏好、系統語言又不在支援清單時的保底語言。
    public static let fallback: AppLanguage = .zhHant

    /// 對應的 `Locale`，注入 SwiftUI Environment（`\.locale`）用。
    public var locale: Locale { Locale(identifier: rawValue) }

    /// 語言選單顯示用的母語名稱（例："繁體中文"、"English"）：固定字串、**不本地化**，
    /// 這樣不論目前介面語言為何，使用者都認得每個選項。
    public var nativeName: String {
        switch self {
        case .zhHant: "繁體中文"
        case .en: "English"
        }
    }
}

extension AppLanguage {
    /// 從 `Locale`（例如 `@Environment(\.locale)`，其值就是根部注入的 `AppLanguage.locale`）反解回
    /// `AppLanguage`。給只能拿到 `Locale` 的呼叫端，要用 ``localizedString(_:bundle:)`` 時換算用。
    /// 查無支援清單 → fallback。
    public init(locale: Locale) {
        self = AppLanguage(rawValue: locale.identifier) ?? .fallback
    }

    /// 明確指定語言解析 String Catalog 字串；不依賴 SwiftUI Environment，給背景通知內容、
    /// 純 Swift 格式化邏輯這類沒有 View 情境的地方用。
    ///
    /// `String(localized:bundle:locale:)` 的 `locale:` 參數**不會**依它選語言（已用 xcodebuild 驗證：
    /// en / zh-Hant 都回 sourceLanguage）。String Catalog 編譯後每個語言仍落在傳統
    /// `xx.lproj/Localizable.strings`，故改用明確開該語言的 lproj 子 bundle 查表，是唯一驗證有效的作法。
    ///
    /// - Parameters:
    ///   - key: String Catalog 的 key；含格式符（如 `"plan.setCountUnit %lld"`）時呼叫端自行
    ///     `String(format:)` 套參數。
    ///   - bundle: 該 package 的資源 bundle（呼叫端傳 `.module`）。
    public func localizedString(_ key: String, bundle: Bundle) -> String {
        let languageBundle = bundle.path(forResource: rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? bundle
        return languageBundle.localizedString(forKey: key, value: nil, table: "Localizable")
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
