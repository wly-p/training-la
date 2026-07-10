import Foundation
import HistoryDomain
import SharedKernel
import SpecDomain
import TrainingDomain

/// 把 Training 的紀錄 ＋ Spec 的動作名稱組成 History 需要的顯示型別。
/// History / Training / Spec 三個 domain 互不相識，只在這裡（Composition Root）接線。
struct HistoryReadingAdapter: WorkoutHistoryReading {
    let workoutRepository: any WorkoutRepository
    let listExercises: ListExercises

    private func exerciseIndex() async throws -> [UUID: Exercise] {
        let all = try await listExercises(muscleGroup: nil)
        return Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }

    func workouts() async throws -> [HistoryWorkoutSummary] {
        try await workoutRepository.finishedWorkouts().map(Self.summary(of:))
    }

    func workoutDetail(id: UUID) async throws -> HistoryWorkoutDetail? {
        guard let workout = try await workoutRepository.get(id: id) else { return nil }
        let names = try await exerciseIndex()
        let blocks = workout.blocks.map { block in
            HistoryBlock(
                id: block.exerciseIndex,
                exerciseName: names[block.exerciseId]?.name ?? "動作",
                sets: block.sets.map(Self.line(from:))
            )
        }
        return HistoryWorkoutDetail(summary: Self.summary(of: workout), note: workout.note, blocks: blocks)
    }

    func exercisesWithHistory() async throws -> [HistoryExerciseOption] {
        let names = try await exerciseIndex()
        let workouts = try await workoutRepository.finishedWorkouts()
        let usedIds = Set(workouts.flatMap { $0.sets.map(\.exerciseId) })
        return usedIds
            .compactMap { id -> HistoryExerciseOption? in
                guard let exercise = names[id] else { return nil }
                return HistoryExerciseOption(id: id, name: exercise.name, muscleGroup: exercise.muscleGroup)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func sessions(exerciseId: UUID) async throws -> [HistoryExerciseSession] {
        let records = try await workoutRepository.exerciseHistory(exerciseId: exerciseId)
        // records 已按日期新到舊；依 workoutId 分組，維持順序
        var order: [UUID] = []
        var grouped: [UUID: (day: DayDate, sets: [HistorySetLine])] = [:]
        for record in records {
            if grouped[record.workoutId] == nil {
                order.append(record.workoutId)
                grouped[record.workoutId] = (record.day, [])
            }
            grouped[record.workoutId]?.sets.append(Self.line(from: record.set))
        }
        return order.map { id in
            let entry = grouped[id]!
            return HistoryExerciseSession(id: id, day: entry.day, sets: entry.sets)
        }
    }

    // MARK: - Mapping

    private static func summary(of workout: Workout) -> HistoryWorkoutSummary {
        let duration: Int?
        if let start = workout.startedAt, let end = workout.endedAt {
            duration = max(0, Int(end.timeIntervalSince(start) / 60))
        } else {
            duration = nil
        }
        return HistoryWorkoutSummary(
            id: workout.id,
            day: workout.day,
            exerciseCount: workout.blocks.count,
            totalSets: workout.sets.count,
            overallFeeling: workout.overallFeeling,
            durationMinutes: duration
        )
    }

    private static func line(from set: WorkoutSet) -> HistorySetLine {
        HistorySetLine(
            id: set.id,
            setIndex: set.setIndex,
            weight: set.weight,
            reps: set.reps,
            status: set.status,
            targetWeight: set.targetWeight,
            targetReps: set.targetReps
        )
    }
}
