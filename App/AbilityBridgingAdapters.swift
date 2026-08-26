import AbilityDomain
import Foundation
import SharedKernel
import SpecDomain
import TrainingDomain

/// Ability 的「有練過的動作」port ← Training 的已完成場次 ＋ Spec 的動作名稱。
/// 每個動作只留最近一次表現（`finishedWorkouts()` 已是新到舊，取每個 exerciseId 第一次出現即可）。
struct PracticedExerciseListerAdapter: PracticedExerciseLister {
    let workoutRepository: any WorkoutRepository
    let listExercises: ListExercises

    func practicedExercises() async throws -> [PracticedExercise] {
        let workouts = try await workoutRepository.finishedWorkouts()
        // 帶整個 Exercise 而不只是名稱：同名動作要靠器材分辨。
        let catalog = Dictionary(uniqueKeysWithValues: try await listExercises(muscleGroup: nil).map { ($0.id, $0) })

        // 最近一次：finishedWorkouts() 已是新到舊，每個動作第一次出現的就是。
        // 最大重量：要掃完整個歷史，不能只看最近一次 —— 能力值的定義是「推過的最大」，
        // 上一次是輕重量恢復日的話，拿它當建議會把使用者的能力值往下拉。
        var firstSeen: [UUID: (set: WorkoutSet, day: DayDate)] = [:]
        var maxWeights: [UUID: Weight] = [:]
        var order: [UUID] = []
        for workout in workouts {
            // 熱身組不進能力值：能力值的定義是「推過的最大」，熱身會把它往下拉。
            for set in workout.sets where set.status == .done && !set.isWarmup {
                if firstSeen[set.exerciseId] == nil {
                    firstSeen[set.exerciseId] = (set, workout.day)
                    order.append(set.exerciseId)
                }
                if let current = maxWeights[set.exerciseId] {
                    maxWeights[set.exerciseId] = Swift.max(current, set.weight)
                } else {
                    maxWeights[set.exerciseId] = set.weight
                }
            }
        }

        return order.compactMap { exerciseId in
            guard let exercise = catalog[exerciseId],
                  let last = firstSeen[exerciseId],
                  let maxWeight = maxWeights[exerciseId]
            else { return nil }
            return PracticedExercise(
                exerciseId: exerciseId,
                exerciseName: exercise.name,
                equipment: exercise.equipment,
                maxWeight: maxWeight,
                lastWeight: last.set.weight,
                lastReps: last.set.reps,
                lastPerformedOn: last.day
            )
        }
    }
}
