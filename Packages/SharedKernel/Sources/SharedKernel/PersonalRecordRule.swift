import Foundation

/// 個人紀錄（PR）的判定規則——**全 app 唯一的一份**。
///
/// 為什麼放 SharedKernel：Training（完成訓練摘要的 PR 播報）與 History（單一動作趨勢圖的
/// 獎盃標記）各自需要它，而兩個 package 不互相 import。原本各留一份「薄的純函式版本」，
/// 結果兩份規則悄悄長歪了——完成摘要要求「該維度先前真的出現過」才算新高，
/// 趨勢圖卻拿 0 當基準，於是同一場可能在摘要沒有 PR、在趨勢圖卻有獎盃（體檢 P4-4）。
/// 這是純值邏輯（只吃 `Weight` 與次數，無框架、無 I/O），放共用層剛好。
///
/// ## 規則：以「歷來最重」為主軸
///
/// 一場的代表組（最重的一組，同重量取次數最多）符合以下任一條件就算 PR：
///
/// 1. **重量創新高** — 比歷來任何一組都重
/// 2. **同重量下次數創新高** — 重量追平過去某次，但做得更多下
///
/// 第一次練這個動作＝PR（那本來就是你的最佳紀錄）。
///
/// 舊的兩套規則都會漏掉一種常見情況：歷史有 `90kg × 8`、這次做 `100kg × 5`。
/// 「100kg 這個重量」沒出現過、「5 下這個次數」也沒出現過，嚴格版判定無 PR；
/// 寬鬆版則因為 `5 > 0` 判定有 PR，但理由是錯的。新規則直接答「100 > 90，重量創新高」。
///
/// 比較一律用 `Weight` 本身（它的 `==`／`<` 已經換算單位），**不要退回 `.value`**：
/// 那會讓 100 lb 和 100 kg 被當成同一個重量、並互相判成創新高。
public enum PersonalRecordRule {
    /// PR 的種類，供呼叫端決定文案。
    public enum Kind: Equatable, Sendable {
        /// 比歷來任何一組都重。
        case newWeight
        /// 重量追平過去，但同重量下次數創新高。
        case newRepsAtWeight
        /// 這個動作的第一筆紀錄。
        case firstEver
    }

    /// 一組的成績（判定只需要這兩個值）。
    public struct Performance: Equatable, Sendable {
        public let weight: Weight
        public let reps: Int

        public init(weight: Weight, reps: Int) {
            self.weight = weight
            self.reps = reps
        }
    }

    /// 一組成績跟「先前的歷史」比，是不是 PR。
    ///
    /// - Parameters:
    ///   - candidate: 這一場的代表組。
    ///   - history: **先前**所有場次的組，不含 candidate 自己那一場。順序不影響結果。
    /// - Returns: PR 的種類；不是 PR 回 `nil`。
    public static func evaluate(
        _ candidate: Performance,
        against history: [Performance]
    ) -> Kind? {
        guard let heaviestEver = history.map(\.weight).max() else { return .firstEver }
        if candidate.weight > heaviestEver { return .newWeight }
        let bestRepsAtSameWeight = history
            .filter { $0.weight == candidate.weight }
            .map(\.reps)
            .max()
        if let best = bestRepsAtSameWeight, candidate.reps > best { return .newRepsAtWeight }
        return nil
    }

    /// 一場之中「代表這個動作」的那一組：最重的一組，同重量取次數最多。
    /// 兩個呼叫端原本各寫一次同樣的 `max(by:)`，一併收進來。
    public static func representative(of performances: [Performance]) -> Performance? {
        performances.max { ($0.weight, $0.reps) < ($1.weight, $1.reps) }
    }
}
