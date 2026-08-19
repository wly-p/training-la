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

    public func finishedWorkouts(limit: Int?) async throws -> [Workout] {
        var descriptor = FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.day, order: .reverse), SortDescriptor(\.startedAt, order: .reverse)]
        )
        // 上限交給 SwiftData，不要撈回全部才在記憶體裡砍——成本在 toDomain()
        // 把每一場的每一組都轉成 struct，那正是要避開的部分。
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func exerciseHistory(exerciseId: UUID) async throws -> [ExerciseSetRecord] {
        // 直接以 exerciseId 撈組，不要先撈全部場次再過濾。
        //
        // 原本是「抓所有已完成場次 → 每一場都 toDomain()（含它的每一組）→ 才挑出這個動作」，
        // 所以完全沒有這個動作的場次也被完整轉換一次。而 DetectPersonalRecords 會對
        // 這場的每一個動作各呼叫一次——結束一場 5 個動作的訓練＝5 次全庫掃描。
        // 200 場 × 25 組的資料量下實測單次 0.27s、五次 1.37s，全都卡在結束訓練的當下。
        let descriptor = FetchDescriptor<WorkoutSetModel>(
            predicate: #Predicate { $0.exerciseId == exerciseId }
        )
        // 已完成場次才算數（進行中的那場不該進歷史）；排序沿用「新到舊」的既有語意。
        // 關聯的 workout 在同一個 context 裡，取用不會再打一次 DB。
        return try modelContext.fetch(descriptor)
            .compactMap { setModel -> (model: WorkoutModel, record: ExerciseSetRecord)? in
                guard let workout = setModel.workout, workout.endedAt != nil else { return nil }
                let day = DayDate(isoString: workout.day) ?? DayDate(year: 1970, month: 1, day: 1)
                return (workout, ExerciseSetRecord(
                    workoutId: workout.id, day: day, set: setModel.toDomain()
                ))
            }
            .sorted { lhs, rhs in
                if lhs.record.day != rhs.record.day { return lhs.record.day > rhs.record.day }
                let l = lhs.model.startedAt ?? .distantPast
                let r = rhs.model.startedAt ?? .distantPast
                if l != r { return l > r }
                // 同一場內維持 (exerciseIndex, setIndex) 的自然順序，輸出才穩定。
                return (lhs.record.set.exerciseIndex, lhs.record.set.setIndex)
                    < (rhs.record.set.exerciseIndex, rhs.record.set.setIndex)
            }
            .map(\.record)
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
