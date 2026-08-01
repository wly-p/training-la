import AbilityDomain
import Foundation
import SharedKernel

@MainActor
@Observable
public final class AbilityListViewModel {
    /// 一列：動作＋目前能力值（可能還沒設定）＋推算建議（跟目前值不同才會有值）。
    public struct Row: Identifiable, Equatable {
        public let exerciseId: UUID
        public let exerciseName: String
        /// 器材：同名動作（肩推有三筆）靠它分辨，1RM 各自獨立。
        public let equipment: Equipment
        public let current: AbilityValue?
        public let suggestion: Weight?
        public var id: UUID { exerciseId }
    }

    private let listAbilityValues: ListAbilityValues
    private let setAbilityValue: SetAbilityValue
    private let practicedLister: any PracticedExerciseLister
    private let suggest: SuggestAbilityValue

    public private(set) var rows: [Row] = []

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

    public func load() async {
        do {
            let practiced = try await practicedLister.practicedExercises()
            let existing = Dictionary(uniqueKeysWithValues: try await listAbilityValues().map { ($0.exerciseId, $0) })
            rows = practiced
                .map { p in
                    let current = existing[p.exerciseId]
                    let suggested = suggest(weight: p.lastWeight, reps: p.lastReps)
                    // 只有跟目前的值不同才算「建議」，不然每次都提示同一個數字很煩。
                    let suggestion = (current?.value == suggested) ? nil : suggested
                    return Row(
                        exerciseId: p.exerciseId, exerciseName: p.exerciseName,
                        equipment: p.equipment, current: current, suggestion: suggestion
                    )
                }
                .sorted { $0.exerciseName < $1.exerciseName }
        } catch {
            rows = []
        }
    }

    /// 手動填值（`9a` 骨架的 ValuePicker 確認）。
    public func setValue(exerciseId: UUID, value: Weight) async {
        _ = try? await setAbilityValue(exerciseId: exerciseId, value: value, source: .manual)
        await load()
    }

    /// 接受推算建議（`source: .estimated`，跟手動填分開標記）。
    public func acceptSuggestion(_ row: Row) async {
        guard let suggestion = row.suggestion else { return }
        _ = try? await setAbilityValue(exerciseId: row.exerciseId, value: suggestion, source: .estimated)
        await load()
    }
}
