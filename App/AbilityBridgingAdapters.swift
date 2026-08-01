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
        var seen: Set<UUID> = []
        var result: [PracticedExercise] = []
        for workout in workouts {
            for set in workout.sets where !seen.contains(set.exerciseId) {
                seen.insert(set.exerciseId)
                guard let exercise = catalog[set.exerciseId] else { continue }
                result.append(PracticedExercise(
                    exerciseId: set.exerciseId, exerciseName: exercise.name,
                    equipment: exercise.equipment, lastWeight: set.weight, lastReps: set.reps
                ))
            }
        }
        return result
    }
}
