import Foundation
import SharedKernel
import SwiftData
import TrainingDomain

@ModelActor
public actor SwiftDataWorkoutRepository: WorkoutRepository {
    /// 整包 upsert：對外語意仍是「整包取代」（對齊 API 的 aggregate 寫入），
    /// 但對內是 diff——只動真的變了的列。
    ///
    /// 原本的做法是「已存在就先刪整棵（cascade 帶走 sets）再重插」。而 `ActiveWorkoutViewModel`
    /// 每記一組就 `saveProgress(workout)` 一次，所以一場 30 組 ＝ 30 次「刪 N 列 ＋ 插 N+1 列」，
    /// 總寫入量 O(n²)。落地磁碟實測：30 組 0.095s、60 組 0.340s——組數翻倍耗時變 3.6 倍，
    /// 正是 O(n²) 的簽名。改後是 0.048s / 0.148s，單次 save 的磁碟寫入降成 O(1)
    /// （量測與完整數字見 `WritePathBenchmark`）。
    ///
    /// 「對齊 API 的整包取代」是**網路層**的契約，本地 SwiftData 沒有理由跟著自殘；
    /// 呼叫端拿到的行為完全一樣（傳入什麼就是最終狀態），protocol 簽章也沒變。
    ///
    /// 這同時是 CloudKit 的前置條件：刪整棵再重插到了同步層會變成「一次訓練數百次 record 異動」，
    /// 改成 diff 之後才有得談（見 Backlog 的 CloudKit 評估票）。
    public func save(_ workout: Workout) async throws {
        guard let existing = try fetchModel(id: workout.id) else {
            modelContext.insert(WorkoutModel(from: workout))
            try modelContext.save()
            return
        }
        existing.applyScalars(from: workout)

        // sets 依 id 三向 diff。傳入的就是最終狀態：既有但不在傳入裡的要刪掉，
        // 這樣才維持「整包取代」的語意（`saveReplacesAggregate` 釘的就是這條）。
        var incoming = Dictionary(workout.sets.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        // 先取快照再走訪：delete 會就地改動 existing.sets，邊走邊刪會漏掉元素。
        for setModel in Array(existing.sets) {
            if let set = incoming.removeValue(forKey: setModel.id) {
                setModel.apply(set)
            } else {
                // 明確刪掉，不只是從陣列移除——後者會留下沒有 workout 的孤兒列。
                modelContext.delete(setModel)
            }
        }
        // 剩下的是新組。依 workout.sets 的順序 append，inverse 會把 workout 指回來。
        for set in workout.sets where incoming.removeValue(forKey: set.id) != nil {
            existing.sets.append(WorkoutSetModel(from: set))
        }
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
