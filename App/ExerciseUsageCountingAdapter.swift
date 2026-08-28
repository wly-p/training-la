import Foundation
import SpecDomain
import TrainingDomain

/// Spec 的「每個動作練過幾次」port ← Training 的已完成訓練紀錄。
///
/// 動作庫的「常用」分組要依使用頻率排序，但頻率資料在訓練紀錄裡，而 Spec 不依賴 Training。
/// 由 Composition Root 接線（同 `ExerciseUsageLister` 把 Plan 的資料接給 Spec 的作法）。
///
/// **計次單位是場次不是組數**：一場練 5 組臥推只算 1 次。用組數的話高組數動作會永遠壓過
/// 真正常做的動作——「常用」問的是「你多常做它」，不是「你做了幾組」。
struct ExerciseUsageCountingAdapter: ExerciseUsageCounting {
    let workoutRepository: any WorkoutRepository

    func usageCounts() async throws -> [UUID: Int] {
        // 要完整歷史，不能用 limit：常用是長期習慣的統計，只看最近 60 場會讓
        // 一個練了兩年、最近三個月沒碰的動作直接消失。
        let workouts = try await workoutRepository.finishedWorkouts()
        var counts: [UUID: Int] = [:]
        for workout in workouts {
            // 同一場內同一個動作只計一次，所以先收成 Set 再累加。
            let exercisesInSession = Set(workout.sets.filter { $0.status == .done }.map(\.exerciseId))
            for exerciseId in exercisesInSession {
                counts[exerciseId, default: 0] += 1
            }
        }
        return counts
    }
}
