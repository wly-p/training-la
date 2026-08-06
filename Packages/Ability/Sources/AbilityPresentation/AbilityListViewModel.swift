import AbilityDomain
import Foundation
import SharedKernel

@MainActor
@Observable
public final class AbilityListViewModel {
    /// 一列：動作＋目前能力值（可能還沒設定）＋建議值（跟目前值不同才會有值）。
    public struct Row: Identifiable, Equatable {
        public let exerciseId: UUID
        public let exerciseName: String
        /// 器材：同名動作（肩推有三筆）靠它分辨，最大重量各自獨立。
        public let equipment: Equipment
        public let current: AbilityValue?
        /// 建議值＝歷來推過的最大重量；已經等於目前值時為 nil（不重複提示同一個數字）。
        public let suggestion: Weight?
        /// 編輯頁下方「最近一次做到 X × N」用。
        public let lastWeight: Weight
        public let lastReps: Int
        /// 排序用：未設定的列按最近訓練日期排（近的在前）。
        public let lastPerformedOn: DayDate
        public var id: UUID { exerciseId }

        public var isSet: Bool { current != nil }
        /// 啞鈴的重量是**每邊**，清單與編輯頁都要標出來，否則 20kg 會被誤讀成總重。
        public var isPerSide: Bool { equipment == .dumbbell }
    }

    /// 器材篩選 chip 的選取狀態。第一顆固定是「未設定」——這頁最高頻的任務就是把沒設定的補完。
    public enum Filter: Equatable {
        case all
        case unset
        case equipment(Equipment)
    }

    private let listAbilityValues: ListAbilityValues
    private let setAbilityValue: SetAbilityValue
    private let practicedLister: any PracticedExerciseLister
    private let suggest: SuggestAbilityValue

    /// 全部的列（未經搜尋／篩選）。`visibleRows` 才是畫面要顯示的。
    public private(set) var rows: [Row] = []
    public var searchText: String = ""
    public var filter: Filter = .all

    public init(
        listAbilityValues: ListAbilityValues,
        setAbilityValue: SetAbilityValue,
        practicedLister: any PracticedExerciseLister,
        suggest: SuggestAbilityValue = SuggestAbilityValue()
    ) {
        self.listAbilityValues = listAbilityValues
        self.setAbilityValue = setAbilityValue
        self.practicedLister = practicedLister
        self.suggest = suggest
    }

    // MARK: - 衍生狀態

    public var totalCount: Int { rows.count }
    public var setCount: Int { rows.filter(\.isSet).count }
    public var unsetCount: Int { totalCount - setCount }

    /// 有動作的器材才可以按；沒有任何動作的 chip 由 View 降透明度並停用。
    public func hasExercises(for equipment: Equipment) -> Bool {
        rows.contains { $0.equipment == equipment }
    }

    /// 搜尋比對**動作名 ＋ 器材名**：打「啞鈴」要能撈出全部啞鈴動作。
    public func visibleRows(locale: Locale) -> [Row] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return rows.filter { row in
            let matchesFilter: Bool = switch filter {
            case .all: true
            case .unset: !row.isSet
            case .equipment(let equipment): row.equipment == equipment
            }
            guard matchesFilter else { return false }
            guard !query.isEmpty else { return true }
            return row.exerciseName.localizedCaseInsensitiveContains(query)
                || row.equipment.displayName(locale).localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - 載入

    public func load() async {
        do {
            let practiced = try await practicedLister.practicedExercises()
            let existing = Dictionary(uniqueKeysWithValues: try await listAbilityValues().map { ($0.exerciseId, $0) })
            rows = practiced
                .map { practicedExercise in
                    let current = existing[practicedExercise.exerciseId]
                    let suggested = suggest(maxWeight: practicedExercise.maxWeight)
                    // 只有跟目前的值不同才算「建議」，不然每次都提示同一個數字很煩。
                    let suggestion = (current?.value == suggested) ? nil : suggested
                    return Row(
                        exerciseId: practicedExercise.exerciseId,
                        exerciseName: practicedExercise.exerciseName,
                        equipment: practicedExercise.equipment,
                        current: current,
                        suggestion: suggestion,
                        lastWeight: practicedExercise.lastWeight,
                        lastReps: practicedExercise.lastReps,
                        lastPerformedOn: practicedExercise.lastPerformedOn
                    )
                }
                .sorted(by: Self.ordering)
        } catch {
            rows = []
        }
    }

    /// 已設定的在前；同一組內按最近訓練日期（近的在前），同日再按名稱。
    /// 不用純字母排序——那會讓「剛練完、還沒設定」的動作沉在清單底部，正好是最該被看到的那些。
    private static func ordering(_ lhs: Row, _ rhs: Row) -> Bool {
        if lhs.isSet != rhs.isSet { return lhs.isSet }
        if lhs.lastPerformedOn != rhs.lastPerformedOn {
            return lhs.lastPerformedOn > rhs.lastPerformedOn
        }
        return lhs.exerciseName.localizedStandardCompare(rhs.exerciseName) == .orderedAscending
    }

    // MARK: - 寫入

    /// 手動填值。
    public func setValue(exerciseId: UUID, value: Weight) async {
        _ = try? await setAbilityValue(exerciseId: exerciseId, value: value, source: .manual)
        await load()
    }

    /// 套用建議值（`source: .estimated`，跟手動填分開標記）。
    public func acceptSuggestion(_ row: Row) async {
        guard let suggestion = row.suggestion else { return }
        _ = try? await setAbilityValue(exerciseId: row.exerciseId, value: suggestion, source: .estimated)
        await load()
    }
}
