import Foundation

/// 器材分類。rawValue 為儲存與 API 契約共用的英文 token（對齊 client v0.5.0 的 Equipment）。
public enum Equipment: String, CaseIterable, Codable, Sendable {
    case barbell
    case dumbbell
    case kettlebell
    case hexBar = "hex_bar"
    case machine
    case cable
    case band
    case bodyweight
    case other

    /// 顯示名（跨 domain 的 UI 都用得到，故放 SharedKernel；翻譯見本 package 的 String Catalog）。
    /// 收 `locale` 的理由同 ``MuscleGroup/displayName(_:)``。
    public func displayName(_ locale: Locale) -> String {
        AppLanguage(locale: locale).localizedString("equipment.\(rawValue)", bundle: .module)
    }
}
