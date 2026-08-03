import DesignSystem
import SharedKernel
import SwiftUI
import TrainingDomain

/// 動作庫的動作包成 `PickerSheetItem`：訓練中「加入動作」／13e 換動作用（跟課表/範本加動作
/// 同一套 `PickerSheet`）。CatalogExercise 沒有器材欄位，副標只放肌群。
struct ExercisePickerItem: PickerSheetItem {
    let exercise: CatalogExercise
    /// 副標的肌群名要跟著 app 語言走；本型別不是 View，由建立它的 View 傳進來。
    let locale: Locale
    var id: UUID { exercise.id }
    var title: String { exercise.name }
    var subtitle: String { exercise.muscleGroup.displayName(locale) }
}

/// `PickerSheet` 固定文字（訓練情境）。訓練加動作不提供「新建」（onCreateNew nil），
/// createNew 相關給空字串占位（不會顯示）。
enum TrainingPickerLabels {
    static let standard = PickerSheetLabels(
        cancel: localText("training.cancel"),
        createNewButton: Text(verbatim: ""),
        recentSection: localText("training.picker.recent"),
        allSection: { filter in
            if let filter { localText("training.picker.all") + Text(verbatim: " · \(filter.label)") }
            else { localText("training.picker.all") }
        },
        matchCount: { count in localText("training.picker.matchCount \(count)") },
        createNewRow: { _ in Text(verbatim: "") }
    )
}
