import Foundation
import SharedKernel

/// 內建動作清單的一筆（`Resources/OfficialExercises.json` 的 schema）。
///
/// `id` 是硬寫在 JSON 裡的固定 UUID，不是算出來的：未來官方內容改由 API 供貨時，
/// 這批 id 就是那份契約值（同 `MuscleGroup.rawValue` 的既有精神）。
public struct OfficialExercise: Decodable, Equatable, Sendable {
    public let id: UUID
    /// String Catalog 的 key，例 `exercise.benchPress.barbell`。
    ///
    /// 名稱本身不能當 key：中文會撞（肩推有槓鈴／啞鈴／機械三筆），英文又不是一對一
    /// （肩推 → Overhead Press／Shoulder Press）。
    public let key: String
    public let muscleGroup: MuscleGroup
    public let equipment: Equipment
    /// 這個動作該用什麼量測；JSON 沒寫＝`.weightReps`（絕大多數）。
    public let trackingMode: TrackingMode?

    /// 現在的記錄畫面記得了它嗎。
    ///
    /// 記錄畫面目前只有「重量 × 次數」一種輸入（時間／距離的輸入元件是 B2-ui 那張設計票）。
    /// 棒式、戰繩這類計時動作、雪橇、農夫走路這類計距動作，硬記只能記成「0 kg × N 下」——
    /// 數字沒有意義，還會進歷史、趨勢圖與 PR 判定。與其讓人記一堆假資料，不如先不列出來。
    public var isRecordable: Bool {
        (trackingMode ?? .weightReps) == .weightReps
    }
}

/// App 內建的常見動作（JSON 80 筆，其中 75 筆列出；來源見 `docs/exercise-glossary.md` 表 3）。
///
/// **這些動作不進 SwiftData**：它們是常駐清單，由 `OfficialCatalogExerciseRepository`
/// 在讀取時合併進使用者自建的動作裡。因此沒有「首次啟動 seed 時機」「與既有資料去重」
/// 「官方清單版本管理」這些問題——更新 app 就是更新清單。代價是它們唯讀（不可編輯不可刪）。
public enum OfficialExerciseCatalog {
    /// JSON 裡的全部（含目前不列出的）。依 id 查名稱走這份——見 `listed` 的說明。
    public static let all: [OfficialExercise] = load()

    /// 動作庫與各個動作選擇器看得到的那些：扣掉記錄畫面還記不了的（`isRecordable == false`）。
    ///
    /// 被扣掉的動作**留在 JSON 與翻譯裡**，只是不列出：
    /// - id 是契約值，之後記錄畫面支援時間／距離時，把這個過濾拿掉它們就原封不動回來；
    /// - `exercise(id:)`／`contains(id:)` 仍然認得它們，所以已經引用到的紀錄或課表
    ///   照樣顯示得出名字，不會變成「—」。
    public static let listed: [OfficialExercise] = all.filter(\.isRecordable)

    private static let index: [UUID: OfficialExercise] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func contains(id: UUID) -> Bool { index[id] != nil }

    /// 依當前語言解析名稱後的內建動作；`muscleGroup` 非 nil 時過濾。未排序（由呼叫端合併後統一排）。
    public static func exercises(muscleGroup: MuscleGroup?, language: AppLanguage) -> [Exercise] {
        listed
            .filter { muscleGroup == nil || $0.muscleGroup == muscleGroup }
            .map { make($0, language: language) }
    }

    public static func exercise(id: UUID, language: AppLanguage) -> Exercise? {
        index[id].map { make($0, language: language) }
    }

    private static func make(_ official: OfficialExercise, language: AppLanguage) -> Exercise {
        Exercise(
            id: official.id,
            name: language.localizedString(official.key, bundle: .module),
            muscleGroup: official.muscleGroup,
            equipment: official.equipment,
            description: nil,
            source: .official,
            // 固定時間而非 `Date()`：`Exercise` 是 `Equatable`，每次讀取產生不同時間會讓
            // 比較與 SwiftUI 的 diff 不穩（同一筆動作每次 list 都「變了」）。
            // 這兩個欄位對內建動作沒有意義——它們不進 DB，也不可編輯。
            createdAt: epoch,
            updatedAt: epoch
        )
    }

    private static let epoch = Date(timeIntervalSince1970: 0)

    private static func load() -> [OfficialExercise] {
        guard let url = Bundle.module.url(forResource: "OfficialExercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([OfficialExercise].self, from: data)
        else {
            // 資源是跟著 binary 走的，讀不到代表 build 設定壞了而不是執行期狀況。
            // 不 crash（動作庫少了內建清單仍可用自建動作），但要在 debug 立刻炸出來；
            // 正常性由 `OfficialExerciseCatalogTests` 守著。
            assertionFailure("讀不到 OfficialExercises.json——檢查 Package.swift 的 resources 宣告")
            return []
        }
        return decoded
    }
}
