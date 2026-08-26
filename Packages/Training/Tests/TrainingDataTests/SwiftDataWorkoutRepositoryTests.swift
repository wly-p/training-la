import Foundation
import SharedKernel
import SwiftData
import Testing
import TrainingDomain

@testable import TrainingData

struct SwiftDataWorkoutRepositoryTests {
    private func makeRepository() throws -> any WorkoutRepository {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Schema(TrainingDataFactory.models),
            configurations: config
        )
        return TrainingDataFactory.makeWorkoutRepository(container: container)
    }

    private let kg60 = Weight(value: 60, unit: .kg)
    private let today = DayDate(year: 2026, month: 7, day: 9)

    private func workoutWithSets(_ exerciseId: UUID, reps: [Int], day: DayDate? = nil) -> Workout {
        var workout = Workout(id: UUID(), day: day ?? today, startedAt: Date())
        for count in reps {
            workout.appendSet(exerciseId: exerciseId, measurement: .weightReps(weight: kg60, reps: count))
        }
        return workout
    }

    @Test func saveThenGetRoundTripsWholeTree() async throws {
        let repo = try makeRepository()
        let workout = workoutWithSets(UUID(), reps: [8, 8, 6])

        try await repo.save(workout)
        let fetched = try await repo.get(id: workout.id)

        #expect(fetched == workout)
    }

    @Test func saveReplacesAggregate() async throws {
        let repo = try makeRepository()
        var workout = workoutWithSets(UUID(), reps: [8, 8])
        try await repo.save(workout)

        workout.note = "改了"
        workout.sets.removeLast() // 整包取代：組數可以變少
        try await repo.save(workout)

        let fetched = try await repo.get(id: workout.id)
        #expect(fetched?.note == "改了")
        #expect(fetched?.sets.count == 1)
    }

    @Test func activeWorkoutReturnsUnfinishedOnly() async throws {
        let repo = try makeRepository()
        var finished = workoutWithSets(UUID(), reps: [8])
        finished.endedAt = Date()
        try await repo.save(finished)
        #expect(try await repo.activeWorkout() == nil)

        let active = workoutWithSets(UUID(), reps: [5])
        try await repo.save(active)
        #expect(try await repo.activeWorkout()?.id == active.id)
    }

    @Test func lastPerformanceFindsMostRecentFinishedSets() async throws {
        let repo = try makeRepository()
        let benchPress = UUID()

        var older = workoutWithSets(benchPress, reps: [10, 10], day: DayDate(year: 2026, month: 7, day: 1))
        older.endedAt = Date()
        var newer = workoutWithSets(benchPress, reps: [8, 8, 6], day: DayDate(year: 2026, month: 7, day: 7))
        newer.endedAt = Date()
        let inProgress = workoutWithSets(benchPress, reps: [5]) // 未完成，要被排除
        try await repo.save(older)
        try await repo.save(newer)
        try await repo.save(inProgress)

        let sets = try await repo.lastPerformance(exerciseId: benchPress, excludingWorkout: inProgress.id)

        #expect(sets.map(\.measurement.displayReps) == [8, 8, 6])
    }

    @Test func lastPerformanceEmptyWhenNoHistory() async throws {
        let repo = try makeRepository()
        let sets = try await repo.lastPerformance(exerciseId: UUID(), excludingWorkout: nil)
        #expect(sets.isEmpty)
    }

    @Test func usesExerciseReflectsRecordedSets() async throws {
        let repo = try makeRepository()
        let benchPress = UUID()
        let squat = UUID()
        try await repo.save(workoutWithSets(benchPress, reps: [8, 8]))

        #expect(try await repo.usesExercise(benchPress) == true)
        #expect(try await repo.usesExercise(squat) == false)
    }

    // MARK: - exerciseHistory
    //
    // 這支原本完全沒有測試，而它的查詢在效能修正時被整個重寫
    // （從「撈全部場次再過濾」改成「對 WorkoutSetModel 下 exerciseId predicate」）。
    // 以下把它的四個不變式釘住。

    @Test func exerciseHistoryReturnsOnlyThatExercisesSets() async throws {
        let repo = try makeRepository()
        let squat = UUID(), bench = UUID()
        var workout = Workout(id: UUID(), day: today, startedAt: Date(), endedAt: Date())
        workout.appendSet(exerciseId: squat, measurement: .weightReps(weight: kg60, reps: 5))
        workout.appendSet(exerciseId: bench, measurement: .weightReps(weight: kg60, reps: 8))
        workout.appendSet(exerciseId: squat, measurement: .weightReps(weight: kg60, reps: 4))
        try await repo.save(workout)

        let history = try await repo.exerciseHistory(exerciseId: squat)

        #expect(history.count == 2)
        #expect(history.allSatisfy { $0.set.exerciseId == squat })
        #expect(history.allSatisfy { $0.workoutId == workout.id })
        #expect(history.allSatisfy { $0.day == today })
    }

    /// 進行中的那場不該進歷史——原本靠 `endedAt != nil` 的 predicate 擋，
    /// 改寫後改成走關聯回 workout 判斷，這條要重新釘。
    @Test func exerciseHistoryExcludesUnfinishedWorkouts() async throws {
        let repo = try makeRepository()
        let squat = UUID()
        var finished = Workout(id: UUID(), day: today, startedAt: Date(), endedAt: Date())
        finished.appendSet(exerciseId: squat, measurement: .weightReps(weight: kg60, reps: 5))
        var inProgress = Workout(id: UUID(), day: today, startedAt: Date())   // endedAt = nil
        inProgress.appendSet(exerciseId: squat, measurement: .weightReps(weight: kg60, reps: 99))
        try await repo.save(finished)
        try await repo.save(inProgress)

        let history = try await repo.exerciseHistory(exerciseId: squat)

        #expect(history.count == 1)
        #expect(history.first?.set.measurement.displayReps == 5)
    }

    @Test func exerciseHistoryIsNewestFirst() async throws {
        let repo = try makeRepository()
        let squat = UUID()
        let older = DayDate(year: 2026, month: 7, day: 1)
        let newer = DayDate(year: 2026, month: 7, day: 20)
        for (day, reps) in [(older, 5), (newer, 8)] {
            var w = Workout(id: UUID(), day: day, startedAt: Date(), endedAt: Date())
            w.appendSet(exerciseId: squat, measurement: .weightReps(weight: kg60, reps: reps))
            try await repo.save(w)
        }

        let history = try await repo.exerciseHistory(exerciseId: squat)

        #expect(history.map(\.day) == [newer, older])
    }

    /// 同一場之內要維持 (exerciseIndex, setIndex) 的自然順序，輸出才穩定。
    @Test func exerciseHistoryKeepsSetOrderWithinASession() async throws {
        let repo = try makeRepository()
        let squat = UUID()
        var workout = Workout(id: UUID(), day: today, startedAt: Date(), endedAt: Date())
        for reps in [10, 8, 6] { workout.appendSet(exerciseId: squat, measurement: .weightReps(weight: kg60, reps: reps)) }
        try await repo.save(workout)

        let history = try await repo.exerciseHistory(exerciseId: squat)

        #expect(history.map(\.set.setIndex) == [0, 1, 2])
        #expect(history.map(\.set.measurement.displayReps) == [10, 8, 6])
    }

    @Test func exerciseHistoryIsEmptyForUnknownExercise() async throws {
        let repo = try makeRepository()
        var workout = Workout(id: UUID(), day: today, startedAt: Date(), endedAt: Date())
        workout.appendSet(exerciseId: UUID(), measurement: .weightReps(weight: kg60, reps: 5))
        try await repo.save(workout)

        #expect(try await repo.exerciseHistory(exerciseId: UUID()).isEmpty)
    }

    // MARK: - finishedWorkouts 的上限

    @Test func finishedWorkoutsWithoutLimitReturnsAll() async throws {
        let repo = try makeRepository()
        for offset in 0..<5 {
            try await repo.save(Workout(
                id: UUID(), day: today.adding(days: -offset),
                startedAt: Date(), endedAt: Date()
            ))
        }

        #expect(try await repo.finishedWorkouts().count == 5)
    }

    /// 上限要取**最新**的那幾場，不是任意幾場——訓練首頁的「本週」與「最近練過」都靠這個。
    @Test func finishedWorkoutsWithLimitTakesTheNewest() async throws {
        let repo = try makeRepository()
        for offset in 0..<5 {
            try await repo.save(Workout(
                id: UUID(), day: today.adding(days: -offset),
                startedAt: Date(), endedAt: Date()
            ))
        }

        let recent = try await repo.finishedWorkouts(limit: 2)

        #expect(recent.count == 2)
        #expect(recent.map(\.day) == [today, today.adding(days: -1)])
    }

    @Test func deleteRemovesWorkout() async throws {
        let repo = try makeRepository()
        let workout = workoutWithSets(UUID(), reps: [8])
        try await repo.save(workout)

        try await repo.delete(id: workout.id)

        #expect(try await repo.get(id: workout.id) == nil)
    }
}

/// D1（`save` 改 diff 寫入）專屬。
///
/// 這些釘的是「就地更新」特有的失敗模式：舊的刪除重插實作在這些案例下**也會通過**，
/// 所以以前沒有人寫。反過來說，diff 寫歪的話，上面 `saveReplacesAggregate` 那類
/// 「整包取代」的測試不見得抓得到——會漏的是「該留的列被換掉了」「該刪的列變孤兒」。
struct SwiftDataWorkoutDiffWriteTests {
    /// 要驗「有沒有寫出多餘的列」就得繞過 repository 直接數 row，所以這裡把 container 也交出來。
    private func makeRepositoryAndContainer() throws -> (any WorkoutRepository, ModelContainer) {
        let container = try ModelContainer(
            for: Schema(TrainingDataFactory.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (TrainingDataFactory.makeWorkoutRepository(container: container), container)
    }

    @MainActor
    private func setRowCount(_ container: ModelContainer) throws -> Int {
        try container.mainContext.fetch(FetchDescriptor<WorkoutSetModel>()).count
    }

    private let kg60 = Weight(value: 60, unit: .kg)
    private let today = DayDate(year: 2026, month: 7, day: 9)

    /// 最貼近真實使用的路徑：`ActiveWorkoutViewModel` 每記一組就 save 一次。
    @Test func appendingSetsOneByOneKeepsThemAllInOrder() async throws {
        let (repo, _) = try makeRepositoryAndContainer()
        let exerciseId = UUID()
        var workout = Workout(id: UUID(), day: today, startedAt: Date())

        for i in 0..<30 {
            workout.appendSet(exerciseId: exerciseId, measurement: .weightReps(weight: kg60, reps: 10 - (i % 5)))
            try await repo.save(workout)
        }

        let fetched = try await repo.get(id: workout.id)
        #expect(fetched?.sets.count == 30)
        #expect(fetched == workout)
    }

    /// 改值之後：那一組的 id 不變、值更新、其餘不受波及、沒有多長出列。
    ///
    /// 註：「有沒有真的就地更新」從 repository 的 API 看不出來——`id` 是 domain 給的，
    /// 刪了重建也會帶同一個 id。這支釘的是**可觀察的契約**；真正防止 diff 寫歪的是
    /// 上面那條 row count，以及 `removingAMiddleSetLeavesTheOthersIntact`。
    @Test func editingASetKeepsItsIdentityAndUpdatesValues() async throws {
        let (repo, container) = try makeRepositoryAndContainer()
        var workout = Workout(id: UUID(), day: today, startedAt: Date())
        let exerciseId = UUID()
        workout.appendSet(exerciseId: exerciseId, measurement: .weightReps(weight: kg60, reps: 8))
        workout.appendSet(exerciseId: exerciseId, measurement: .weightReps(weight: kg60, reps: 8))
        try await repo.save(workout)
        let originalIds = workout.sets.map(\.id)

        workout.sets[0].measurement = .weightReps(weight: Weight(value: 65, unit: .kg), reps: 5)
        try await repo.save(workout)

        let fetched = try await repo.get(id: workout.id)
        #expect(fetched?.sets.map(\.id) == originalIds)
        #expect(fetched?.sets[0].measurement.displayWeight == Weight(value: 65, unit: .kg))
        #expect(fetched?.sets[0].measurement.displayReps == 5)
        #expect(fetched?.sets[1].measurement.displayReps == 8)   // 沒被波及
        #expect(try await setRowCount(container) == 2)
    }

    /// 三向 diff 的 delete 分支：拿掉中間那一組，前後兩組要完好。
    @Test func removingAMiddleSetLeavesTheOthersIntact() async throws {
        let (repo, container) = try makeRepositoryAndContainer()
        var workout = Workout(id: UUID(), day: today, startedAt: Date())
        let exerciseId = UUID()
        for reps in [10, 8, 6] {
            workout.appendSet(exerciseId: exerciseId, measurement: .weightReps(weight: kg60, reps: reps))
        }
        try await repo.save(workout)

        let removed = workout.sets[1]
        workout.removeSet(id: removed.id)
        try await repo.save(workout)

        let fetched = try await repo.get(id: workout.id)
        #expect(fetched?.sets.map(\.measurement.displayReps) == [10, 6])
        #expect(fetched?.sets.contains { $0.id == removed.id } == false)
        // 關鍵：被拿掉的那一列是真的刪了，不是只從關聯陣列移除而留成孤兒。
        #expect(try await setRowCount(container) == 2)
    }

    /// 存兩次一模一樣的內容，不該長出重複列或孤兒列。
    @Test func savingUnchangedWorkoutTwiceDoesNotGrowTheStore() async throws {
        let (repo, container) = try makeRepositoryAndContainer()
        var workout = Workout(id: UUID(), day: today, startedAt: Date())
        let exerciseId = UUID()
        for reps in [10, 8, 6] {
            workout.appendSet(exerciseId: exerciseId, measurement: .weightReps(weight: kg60, reps: reps))
        }

        try await repo.save(workout)
        let afterFirst = try await setRowCount(container)
        try await repo.save(workout)

        #expect(afterFirst == 3)
        #expect(try await setRowCount(container) == 3)
        #expect(try await repo.get(id: workout.id) == workout)
    }
}

/// 「上次」預填不能拿到熱身組（B1）。
///
/// 過濾必須發生在 repository 找「最近一場有做這個動作的場次」那個迴圈裡，
/// 不能交給呼叫端：某一場只有熱身組時要**繼續往前找**，回一個空陣列是錯的。
struct LastPerformanceWarmupTests {
    private func makeRepository() throws -> any WorkoutRepository {
        let container = try ModelContainer(
            for: Schema(TrainingDataFactory.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return TrainingDataFactory.makeWorkoutRepository(container: container)
    }

    private let today = DayDate(year: 2026, month: 8, day: 26)

    @Test func lastPerformanceSkipsWarmupSets() async throws {
        let repo = try makeRepository()
        let exerciseId = UUID()
        var workout = Workout(id: UUID(), day: today, startedAt: Date(), endedAt: Date())
        workout.appendSet(exerciseId: exerciseId, measurement: .weightReps(weight: Weight(value: 20, unit: .kg), reps: 15), isWarmup: true)
        workout.appendSet(exerciseId: exerciseId, measurement: .weightReps(weight: Weight(value: 100, unit: .kg), reps: 5))
        try await repo.save(workout)

        let last = try await repo.lastPerformance(exerciseId: exerciseId, excludingWorkout: nil)

        #expect(last.map(\.measurement.displayReps) == [5])
        #expect(last.first?.measurement.displayWeight == Weight(value: 100, unit: .kg))
    }

    /// 關鍵案例：最近一場只做了熱身就收工，要繼續往前找到真正練過的那場。
    @Test func aSessionWithOnlyWarmupsFallsThroughToTheOneBefore() async throws {
        let repo = try makeRepository()
        let exerciseId = UUID()

        var older = Workout(id: UUID(), day: today.adding(days: -3), startedAt: Date(), endedAt: Date())
        older.appendSet(exerciseId: exerciseId, measurement: .weightReps(weight: Weight(value: 95, unit: .kg), reps: 5))
        try await repo.save(older)

        var warmupOnly = Workout(id: UUID(), day: today, startedAt: Date(), endedAt: Date())
        warmupOnly.appendSet(exerciseId: exerciseId, measurement: .weightReps(weight: Weight(value: 20, unit: .kg), reps: 15), isWarmup: true)
        try await repo.save(warmupOnly)

        let last = try await repo.lastPerformance(exerciseId: exerciseId, excludingWorkout: nil)

        // 拿到的是三天前那場的正式組，不是空陣列、也不是今天的熱身
        #expect(last.first?.measurement.displayWeight == Weight(value: 95, unit: .kg))
    }

    /// isWarmup 要能 round-trip（欄位有真的落地，不是只存在記憶體裡）。
    @Test func isWarmupSurvivesSaveAndFetch() async throws {
        let repo = try makeRepository()
        let exerciseId = UUID()
        var workout = Workout(id: UUID(), day: today, startedAt: Date())
        workout.appendSet(exerciseId: exerciseId, measurement: .weightReps(weight: Weight(value: 20, unit: .kg), reps: 15), isWarmup: true)
        workout.appendSet(exerciseId: exerciseId, measurement: .weightReps(weight: Weight(value: 100, unit: .kg), reps: 5))
        try await repo.save(workout)

        let fetched = try await repo.get(id: workout.id)

        #expect(fetched?.sets.map(\.isWarmup) == [true, false])
    }
}

/// 追蹤模式的持久化與遷移（B2-model）。
///
/// **最要緊的是第一支**：既有使用者的每一筆紀錄都沒有 `modeRaw` 這個欄位，
/// 遷移後必須原封不動地讀回「重量 × 次數」。這條錯了就是全部歷史一起變形。
struct SetMeasurementPersistenceTests {
    private func makeRepository() throws -> (any WorkoutRepository, ModelContainer) {
        let container = try ModelContainer(
            for: Schema(TrainingDataFactory.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (TrainingDataFactory.makeWorkoutRepository(container: container), container)
    }

    /// 舊資料沒有 modeRaw／durationSec／distanceM，只有 weightValue ＋ reps。
    /// 直接建一個「沒設過 modeRaw」的列，模擬輕量遷移後的狀態。
    @MainActor
    @Test func rowsWithoutAModeDecodeAsWeightReps() throws {
        let container = try ModelContainer(
            for: Schema(TrainingDataFactory.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let workout = WorkoutModel(
            id: UUID(), day: "2026-08-26", planWorkoutId: nil,
            startedAt: Date(), endedAt: Date(), overallFeeling: nil, note: nil
        )
        // 走 @Model 的預設值路徑：modeRaw 不指定，等同遷移後的舊列。
        let legacy = WorkoutSetModel(
            id: UUID(), exerciseId: UUID(), exerciseIndex: 0, setIndex: 0,
            modeRaw: TrackingMode.weightReps.rawValue,
            weightValue: 100, weightUnitRaw: "kg", reps: 5,
            durationSec: nil, distanceM: nil,
            statusRaw: "done", fromPlanSetId: nil,
            targetModeRaw: TrackingMode.weightReps.rawValue,
            targetWeightValue: nil, targetWeightUnitRaw: nil, targetReps: nil,
            targetDurationSec: nil, targetDistanceM: nil
        )
        workout.sets = [legacy]
        context.insert(workout)
        try context.save()

        #expect(legacy.toDomain().measurement == .weightReps(weight: Weight(value: 100, unit: .kg), reps: 5))
        // 沒有目標快照的舊列（臨時加練）不該憑空長出一個 0kg×0 的目標
        #expect(legacy.toDomain().targetMeasurement == nil)
    }

    /// 認不得的模式字串（未來版本寫回來的）退回 weightReps，不憑空生數字。
    @Test func unknownModeFallsBackToWeightReps() {
        let decoded = SetMeasurementCoding.decode(
            modeRaw: "somethingFromTheFuture", weightValue: 80, weightUnitRaw: "kg",
            reps: 6, durationSec: nil, distanceM: nil
        )

        #expect(decoded == .weightReps(weight: Weight(value: 80, unit: .kg), reps: 6))
    }

    @Test func everyModeRoundTripsThroughTheStore() async throws {
        let (repo, _) = try makeRepository()
        let exerciseId = UUID()
        var workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 8, day: 26), startedAt: Date())
        let measurements: [SetMeasurement] = [
            .weightReps(weight: Weight(value: 100, unit: .kg), reps: 5),
            .reps(12),
            .duration(seconds: 90),
            .distance(meters: 5000),
            .bodyweightPlus(added: Weight(value: 20, unit: .lb), reps: 8),
        ]
        for m in measurements {
            workout.appendSet(exerciseId: exerciseId, measurement: m)
        }
        try await repo.save(workout)

        let fetched = try await repo.get(id: workout.id)

        #expect(fetched?.sets.map(\.measurement) == measurements)
    }

    @Test func targetSnapshotRoundTripsPerMode() async throws {
        let (repo, _) = try makeRepository()
        var workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 8, day: 26), startedAt: Date())
        workout.appendSet(
            exerciseId: UUID(),
            measurement: .duration(seconds: 95),
            targetMeasurement: .duration(seconds: 90)
        )
        try await repo.save(workout)

        let fetched = try await repo.get(id: workout.id)

        #expect(fetched?.sets.first?.targetMeasurement == .duration(seconds: 90))
    }
}
