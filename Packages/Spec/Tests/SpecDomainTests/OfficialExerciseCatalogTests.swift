import Foundation
import SharedKernel
import Testing

@testable import SpecDomain

/// 內建動作清單（`Resources/OfficialExercises.json` ＋ `Localizable.xcstrings`）的完整性。
///
/// 這批資料是手工維護的，最可能的錯是「加了動作卻忘了補翻譯」或「key 打錯撞在一起」，
/// 所以測的是資料本身而不是行為。
struct OfficialExerciseCatalogTests {
    /// `docs/exercise-glossary.md` 表 3 的筆數。改動清單時這個數字要一起改，
    /// 免得「不小心刪掉幾筆」這種事悄悄過關。
    private static let expectedCount = 80

    @Test func jsonLoadsCompletely() {
        // 解不出來（例如 muscleGroup 打錯字）時 `all` 會是空陣列，所以這條同時守住 rawValue 有效性。
        #expect(OfficialExerciseCatalog.all.count == Self.expectedCount)
    }

    @Test func idsAndKeysAreUnique() {
        let all = OfficialExerciseCatalog.all
        #expect(Set(all.map(\.id)).count == all.count, "有重複的 id")
        #expect(Set(all.map(\.key)).count == all.count, "有重複的 key")
    }

    @Test func everyMuscleGroupFilterReturnsOnlyThatGroup() {
        for group in MuscleGroup.allCases {
            let matched = OfficialExerciseCatalog.exercises(muscleGroup: group, language: .zhHant)
            #expect(matched.allSatisfy { $0.muscleGroup == group })
            #expect(matched.count == OfficialExerciseCatalog.all.filter { $0.muscleGroup == group }.count)
        }
    }

    @Test func nilFilterReturnsEverything() {
        #expect(OfficialExerciseCatalog.exercises(muscleGroup: nil, language: .zhHant).count
                == Self.expectedCount)
    }

    @Test func producedExercisesAreOfficialAndStable() throws {
        let official = try #require(OfficialExerciseCatalog.all.first)
        let first = try #require(OfficialExerciseCatalog.exercise(id: official.id, language: .zhHant))
        let second = try #require(OfficialExerciseCatalog.exercise(id: official.id, language: .zhHant))

        #expect(first.source == .official)
        // 每次讀取都要完全相等：時間戳若用 Date() 會讓同一筆動作在 Equatable / SwiftUI diff 下一直「變了」。
        #expect(first == second)
    }

    @Test func unknownIdIsNotInCatalog() {
        let stranger = UUID()
        #expect(!OfficialExerciseCatalog.contains(id: stranger))
        #expect(OfficialExerciseCatalog.exercise(id: stranger, language: .zhHant) == nil)
    }

    @Test func everyEntryIsInTheCatalogById() {
        #expect(OfficialExerciseCatalog.all.allSatisfy { OfficialExerciseCatalog.contains(id: $0.id) })
    }

    // MARK: - 翻譯齊備

    /// catalog 裡每個 key 有翻譯的語言集合。
    ///
    /// 直接讀 `.xcstrings` 而不是斷言 `exercise(id:language:)` 的名稱：`swift test` 走 SwiftPM，
    /// 而 **SwiftPM 不編譯 String Catalog**（只有 Xcode 會編成 `xx.lproj/Localizable.strings`），
    /// 在這裡查表一律回 key 本身。同 `SharedKernelTests/EnumLocalizationTests` 的作法。
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
                return !((unit?["value"] as? String) ?? "").isEmpty
            }
            result[entry.key] = Set(translated.keys)
        }
    }()

    private static let requiredLanguages = Set(AppLanguage.allCases.map(\.rawValue))

    @Test func everyExerciseHasAllTranslations() {
        for official in OfficialExerciseCatalog.all {
            #expect(Self.catalog[official.key] == Self.requiredLanguages, "\(official.key) 的翻譯不齊")
        }
    }

    @Test func catalogHasNoOrphanKeys() {
        let used = Set(OfficialExerciseCatalog.all.map(\.key))
        let orphans = Set(Self.catalog.keys).subtracting(used)
        #expect(orphans.isEmpty, "catalog 有沒人用的 key：\(orphans.sorted())")
    }
}
