import Foundation

/// 肌群分類。rawValue 為儲存與 API 契約共用的英文 token。
public enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case core
    case functional
    case other

    /// 顯示名（跨 domain 的 UI 都用得到，故放 SharedKernel；翻譯見本 package 的 String Catalog）。
    ///
    /// 收 `locale` 而不是回傳固定字串：語言要跟著 app 的設定走，而 enum 拿不到 SwiftUI Environment。
    /// 呼叫端在 View 裡 `@Environment(\.locale) private var locale` 後傳進來。
    public func displayName(_ locale: Locale) -> String {
        AppLanguage(locale: locale).localizedString("muscleGroup.\(rawValue)", bundle: .module)
    }

    /// 圓章用的縮寫（1–2 字）。
    ///
    /// 不能拿 `displayName` 砍字首：英文的 Chest 與 Core 都是 `C`，砍完會撞在一起，
    /// 而 Functional 砍兩個字母是沒有意義的 `Fu`。縮寫是獨立的翻譯，不是顯示名的衍生物。
    public func badgeText(_ locale: Locale) -> String {
        AppLanguage(locale: locale).localizedString("muscleGroup.\(rawValue).badge", bundle: .module)
    }
}
