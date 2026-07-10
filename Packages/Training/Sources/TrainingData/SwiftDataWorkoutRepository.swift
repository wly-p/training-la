import Foundation
import SharedKernel
import SwiftData
import TrainingDomain

@ModelActor
public actor SwiftDataWorkoutRepository: WorkoutRepository {
    /// 整包 upsert：已存在就先刪整棵（cascade 帶走 sets）再重插，對齊 API 的「整包取代」語意。
    public func save(_ workout: Workout) async throws {
        if let existing = try fetchModel(id: workout.id) {
            modelContext.delete(existing)
        }
        modelContext.insert(WorkoutModel(from: workout))
        try modelContext.save()
    }

    public func get(id: UUID) async throws -> Workout? {
        try fetchModel(id: id)?.toDomain()
    }

    public func delete(id: UUID) async throws {
        guard let model = try fetchModel(id: id) else {
            throw WorkoutRepositoryError.notFound(id: id)
        }
        modelContext.delete(model)
        try modelContext.save()
    }

    public func activeWorkout() async throws -> Workout? {
        var descriptor = FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    public func lastPerformance(exerciseId: UUID, excludingWorkout: UUID?) async throws -> [WorkoutSet] {
        // 已完成場次由新到舊掃，取第一個包含該動作的場次
        let predicate: Predicate<WorkoutModel>
        if let excluded = excludingWorkout {
            predicate = #Predicate { $0.endedAt != nil && $0.id != excluded }
        } else {
            predicate = #Predicate { $0.endedAt != nil }
        }
        var descriptor = FetchDescriptor<WorkoutModel>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.day, order: .reverse), SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        for model in try modelContext.fetch(descriptor) {
            let matched = model.sets
                .filter { $0.exerciseId == exerciseId }
                .map { $0.toDomain() }
                .sorted { ($0.exerciseIndex, $0.setIndex) < ($1.exerciseIndex, $1.setIndex) }
            if !matched.isEmpty {
                return matched
            }
        }
        return []
    }

    public func finishedWorkouts() async throws -> [Workout] {
        let descriptor = FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.day, order: .reverse), SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func exerciseHistory(exerciseId: UUID) async throws -> [ExerciseSetRecord] {
        let descriptor = FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.day, order: .reverse), SortDescriptor(\.startedAt, order: .reverse)]
        )
        var records: [ExerciseSetRecord] = []
        for model in try modelContext.fetch(descriptor) {
            let workout = model.toDomain()
            for set in workout.sets where set.exerciseId == exerciseId {
                records.append(ExerciseSetRecord(workoutId: workout.id, day: workout.day, set: set))
            }
        }
        return records
    }

    public func usesExercise(_ exerciseId: UUID) async throws -> Bool {
        var descriptor = FetchDescriptor<WorkoutSetModel>(
            predicate: #Predicate { $0.exerciseId == exerciseId }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first != nil
    }

    private func fetchModel(id: UUID) throws -> WorkoutModel? {
        var descriptor = FetchDescriptor<WorkoutModel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
