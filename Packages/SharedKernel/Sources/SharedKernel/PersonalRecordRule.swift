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
        /// 純次數模式：做得比以前多。
        case newReps
        /// 時間模式：撐得比以前久。
        case newDuration
        /// 距離模式：跑得比以前遠。
        case newDistance
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

// MARK: - 各追蹤模式

extension PersonalRecordRule {
    /// 各模式各自比，**跨模式永遠不比較**。
    ///
    /// 刻意**不跟 `Performance` 版多載同名**：同名多載要靠型別推論決定挑哪一支，
    /// 而這支檔案存在的理由就是「判定規則只能有一份、不能悄悄長歪」。
    /// 名字不同，呼叫端讀起來就知道自己在用哪一套。
    ///
    /// 「撐 90 秒」跟「推 100 公斤」之間沒有大小關係，硬要換算只會得到假的紀錄。
    /// 所以判定前先把歷史濾成跟候選同一個模式；那個模式沒有歷史＝這是第一筆。
    ///
    /// 一個動作的模式是固定的（`Exercise.trackingMode`），所以實務上歷史本來就同模式；
    /// 濾這一道是為了使用者中途改了動作的模式時不會拿舊資料亂比。
    public static func evaluateMeasurement(
        _ candidate: SetMeasurement,
        against history: [SetMeasurement]
    ) -> Kind? {
        let sameMode = history.filter { $0.mode == candidate.mode }
        guard !sameMode.isEmpty else { return .firstEver }

        switch candidate {
        case .weightReps(let weight, let reps):
            return evaluate(
                Performance(weight: weight, reps: reps),
                against: sameMode.compactMap(Performance.init(measurement:))
            )
        case .bodyweightPlus(let added, let reps):
            return evaluate(
                Performance(weight: added, reps: reps),
                against: sameMode.compactMap(Performance.init(measurement:))
            )
        case .reps(let count):
            let best = sameMode.compactMap { if case .reps(let r) = $0 { r } else { nil } }.max()
            return best.map { count > $0 ? .newReps : nil } ?? .firstEver
        case .duration(let seconds):
            let best = sameMode.compactMap { if case .duration(let s) = $0 { s } else { nil } }.max()
            return best.map { seconds > $0 ? .newDuration : nil } ?? .firstEver
        case .distance(let meters):
            let best = sameMode.compactMap { if case .distance(let m) = $0 { m } else { nil } }.max()
            return best.map { meters > $0 ? .newDistance : nil } ?? .firstEver
        }
    }

    /// 一場之中代表這個動作的那一組。各模式的「最好」定義不同：
    /// 帶重量的比 (重量, 次數)、純次數比次數、時間比秒數、距離比公尺。
    ///
    /// 混模式時只在**第一組的模式**裡挑——一個動作的模式是固定的，
    /// 真的混到了代表這場資料有問題，挑跨模式的「最大值」只會讓錯誤更難看出來。
    public static func representativeMeasurement(of measurements: [SetMeasurement]) -> SetMeasurement? {
        guard let mode = measurements.first?.mode else { return nil }
        let sameMode = measurements.filter { $0.mode == mode }
        return sameMode.max { lhs, rhs in
            switch (lhs, rhs) {
            case (.weightReps(let lw, let lr), .weightReps(let rw, let rr)):
                (lw, lr) < (rw, rr)
            case (.bodyweightPlus(let lw, let lr), .bodyweightPlus(let rw, let rr)):
                (lw, lr) < (rw, rr)
            case (.reps(let l), .reps(let r)): l < r
            case (.duration(let l), .duration(let r)): l < r
            case (.distance(let l), .distance(let r)): l < r
            default: false   // 已經濾成同模式，走不到
            }
        }
    }
}

extension PersonalRecordRule.Performance {
    /// 帶重量的模式才轉得出 `Performance`；其餘回 nil。
    init?(measurement: SetMeasurement) {
        switch measurement {
        case .weightReps(let weight, let reps), .bodyweightPlus(let weight, let reps):
            self.init(weight: weight, reps: reps)
        case .reps, .duration, .distance:
            return nil
        }
    }
}
