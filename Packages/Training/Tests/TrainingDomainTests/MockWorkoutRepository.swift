import Foundation
import SharedKernel
import TrainingDomain

actor MockWorkoutRepository: WorkoutRepository {
    private(set) var storage: [UUID: Workout] = [:]
    var stubbedLastPerformance: [UUID: [WorkoutSet]] = [:]

    func seed(_ workouts: [Workout]) {
        for workout in workouts {
            storage[workout.id] = workout
        }
    }

    func stubLastPerformance(exerciseId: UUID, sets: [WorkoutSet]) {
        stubbedLastPerformance[exerciseId] = sets
    }

    func save(_ workout: Workout) async throws {
        storage[workout.id] = workout
    }

    func get(id: UUID) async throws -> Workout? {
        storage[id]
    }

    func delete(id: UUID) async throws {
        guard storage.removeValue(forKey: id) != nil else {
            throw WorkoutRepositoryError.notFound(id: id)
        }
    }

    func activeWorkout() async throws -> Workout? {
        storage.values
            .filter { !$0.isFinished }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
            .first
    }

    func lastPerformance(exerciseId: UUID, excludingWorkout: UUID?) async throws -> [WorkoutSet] {
        stubbedLastPerformance[exerciseId] ?? []
    }

    func finishedWorkouts() async throws -> [Workout] {
        storage.values
            .filter { $0.isFinished }
            .sorted { $0.day > $1.day }
    }

    func exerciseHistory(exerciseId: UUID) async throws -> [ExerciseSetRecord] {
        storage.values
            .filter { $0.isFinished }
            .sorted { $0.day > $1.day }
            .flatMap { workout in
                workout.sets
                    .filter { $0.exerciseId == exerciseId }
                    .map { ExerciseSetRecord(workoutId: workout.id, day: workout.day, set: $0) }
            }
    }

    func usesExercise(_ exerciseId: UUID) async throws -> Bool {
        storage.values.contains { $0.sets.contains { $0.exerciseId == exerciseId } }
    }
}

actor SpyPlanProgress: PlanProgressRecorder {
    private(set) var markedDone: [UUID] = []

    func markDone(planWorkoutId: UUID) async throws {
        markedDone.append(planWorkoutId)
    }
}
