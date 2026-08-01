import Foundation
import Testing

@testable import SharedKernel

/// `MuscleGroup` / `Equipment` 的顯示名翻譯是否齊備。
///
/// 為什麼直接讀 `Localizable.xcstrings` 而不是斷言 `displayName(_:)` 的回傳值：
/// `swift test` 走 SwiftPM，而 **SwiftPM 不編譯 String Catalog**（只有 Xcode 會把 `.xcstrings`
/// 編成 `xx.lproj/Localizable.strings`），所以在這裡查表一律回 key 本身，斷言字面值毫無意義。
/// 改成檢查 catalog 的內容，反而能抓到真正會出事的情況：**新增 enum case 卻忘了補翻譯**。
struct EnumLocalizationTests {
    /// catalog 裡每個 key 有翻譯的語言集合。
    private static let catalog: [String: Set<String>] = {
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: Any]
        else { return [:] }

        return strings.reduce(into: [:]) { result, entry in
            let localizations = (entry.value as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            let translated = localizations.filter { _, value in
                let unit = (value as? [String: Any])?["stringUnit"] as? [String: Any]
                let text = unit?["value"] as? String
                return !(text ?? "").isEmpty
            }
            result[entry.key] = Set(translated.keys)
        }
    }()

    /// 目前支援的語言都得有值，少一個就是漏翻。
    private static let requiredLanguages = Set(AppLanguage.allCases.map(\.rawValue))

    @Test func everyMuscleGroupHasAllTranslations() {
        for group in MuscleGroup.allCases {
            let key = "muscleGroup.\(group.rawValue)"
            #expect(Self.catalog[key] == Self.requiredLanguages, "\(key) 的翻譯不齊")
        }
    }

    @Test func everyMuscleGroupHasABadgeAbbreviation() {
        for group in MuscleGroup.allCases {
            let key = "muscleGroup.\(group.rawValue).badge"
            #expect(Self.catalog[key] == Self.requiredLanguages, "\(key) 的縮寫不齊")
        }
    }

    @Test func everyEquipmentHasAllTranslations() {
        for equipment in Equipment.allCases {
            let key = "equipment.\(equipment.rawValue)"
            #expect(Self.catalog[key] == Self.requiredLanguages, "\(key) 的翻譯不齊")
        }
    }

    /// 圓章縮寫必須兩兩相異。
    /// 這正是舊寫法（砍 `displayName` 的字首）壞掉的地方：英文的 Chest 與 Core 都會變成 `C`。
    @Test func badgeAbbreviationsAreUniquePerLanguage() throws {
        let url = try #require(Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"))
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let strings = try #require(root?["strings"] as? [String: Any])

        for language in Self.requiredLanguages {
            let abbreviations = MuscleGroup.allCases.compactMap { group -> String? in
                let entry = strings["muscleGroup.\(group.rawValue).badge"] as? [String: Any]
                let localizations = entry?["localizations"] as? [String: Any]
                let unit = (localizations?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
                return unit?["value"] as? String
            }
            #expect(
                Set(abbreviations).count == MuscleGroup.allCases.count,
                "\(language) 的圓章縮寫有重複：\(abbreviations)"
            )
        }
    }
}
