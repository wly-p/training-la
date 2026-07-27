import PlanDomain
import SharedKernel

/// 把 PlanWorkout / WorkoutSpec 的 blocks 轉成表單用的 drafts（簡易編輯，只認絕對值——
/// `.relativeToLast` 會被當成空白待填，這條路徑本來就不會產生它）。
///
/// 舊的 `ExerciseDraftsEditor`／`PlanExercisePickerView`（原生 Form/List）已被
/// `PlanWorkoutFormView` 改用 `EditScaffold`＋`PickerSheet` 取代，只留這個轉換函式。
func draftsFromBlocks(_ blocks: [PlanBlock]) -> [ExerciseTargetDraft] {
    blocks.map { block in
        let first = block.sets[0]
        return ExerciseTargetDraft(
            exerciseId: block.exerciseId,
            setCount: block.sets.count,
            targetWeight: first.targetWeight?.resolvedWeight,
            targetReps: first.targetReps,
            restSec: first.restSec
        )
    }
}
