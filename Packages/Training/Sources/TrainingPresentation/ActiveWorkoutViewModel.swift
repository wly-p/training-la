import Foundation
import Observation
import SharedKernel
import TrainingDomain

@MainActor
@Observable
public final class ActiveWorkoutViewModel {
    public private(set) var workout: Workout
    public private(set) var catalog: [CatalogExercise] = []
    public private(set) var lastPerformances: [UUID: [WorkoutSet]] = [:]
    public private(set) var currentExerciseId: UUID?
    public private(set) var errorMessage: String?
    /// 照課表訓練時的目標藍圖（自由訓練為 nil）。
    public private(set) var blueprint: PlannedWorkoutBlueprint?
    /// 結束或放棄後設為 true，View 觀察到就關閉畫面。
    public private(set) var isDismissed = false

    /// 休息倒數剩餘秒數；nil＝沒在休息。
    public private(set) var restRemaining: Int?
    /// 倒數歸零 → View 彈窗提示「休息結束」。
    public private(set) var restEnded = false
    private var restTask: Task<Void, Never>?
    /// 休息倒數的結束時間點；剩餘秒數一律由它與現在時間換算，背景期間也不失準。
    private var restEndDate: Date?
    /// 目前這段休息的「完整秒數」（起始設定值，非剩餘）；供調整時換算並套用到後續組。
    private var restSeconds: Int?
    /// 目前這段休息屬於哪個動作；調整休息時據此把新值套用到該動作後續各組。
    private var restExerciseId: UUID?
    /// 訓練中手動調整過的休息秒數（按動作記）；有值就蓋過課表原定 restSec，套用到該動作後續各組。
    private var adjustedRestByExercise: [UUID: Int] = [:]
    /// 排/取消通知的非同步工作（fire-and-forget，不擋 UI）；測試可 await 它確認已排。
    var pendingRestNotify: Task<Void, Never>?

    /// 剛做滿某動作的課表組數 → View 顯示完成卡片。
    public private(set) var showExerciseComplete = false
    /// 每個動作只跳一次完成卡片（選「再做一組」後不再重複跳）。
    private var completionShownFor: Set<UUID> = []

    /// 剛記錄（完成/跳過）的那一組 id，供「復原上一組」撤銷用。
    /// 切換動作即清空 → 單層 undo，只撤銷「當下這格剛按的」那組。
    private var lastRecordedSetId: UUID?
    /// 是否有可撤銷的上一組（driving 完成卡片上的復原入口）。
    public var canUndoLastSet: Bool { lastRecordedSetId != nil }
    /// 這一組是不是「剛記錄、可撤銷」的那組（記錄列上的復原鍵只掛在它身上）。
    public func isUndoable(setId: UUID) -> Bool { lastRecordedSetId == setId }

    public var draftWeightValue: Double = 20
    public var draftWeightUnit: WeightUnit = .kg
    public var draftReps: Int = 8

    private let saveProgress: SaveWorkoutProgress
    private let finishWorkout: FinishWorkout
    private let discardWorkout: DiscardWorkout
    private let lastPerformance: LastPerformance
    private let exerciseCatalog: any ExerciseCatalog
    private let plannedProvider: (any PlannedWorkoutProvider)?
    /// 目前時間來源（可注入以測試背景經過時間）。
    private let now: () -> Date
    /// 休息結束的本地通知排程。
    private let notifications: any RestNotificationScheduling

    public init(
        workout: Workout,
        saveProgress: SaveWorkoutProgress,
        finishWorkout: FinishWorkout,
        discardWorkout: DiscardWorkout,
        lastPerformance: LastPerformance,
        exerciseCatalog: any ExerciseCatalog,
        plannedProvider: (any PlannedWorkoutProvider)? = nil,
        notifications: any RestNotificationScheduling = NoopRestNotificationScheduler(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.workout = workout
        self.saveProgress = saveProgress
        self.finishWorkout = finishWorkout
        self.discardWorkout = discardWorkout
        self.lastPerformance = lastPerformance
        self.exerciseCatalog = exerciseCatalog
        self.plannedProvider = plannedProvider
        self.notifications = notifications
        self.now = now
    }

    // MARK: - 衍生狀態

    public var currentBlockSets: [WorkoutSet] {
        guard let id = currentExerciseId else { return [] }
        return workout.blocks.last { $0.exerciseId == id }?.sets ?? []
    }

    /// 目前動作以外、已有紀錄的區塊（畫面下方的摘要）。
    public var otherBlocks: [ExerciseBlock] {
        let currentIndex = workout.blocks.last { $0.exerciseId == currentExerciseId }?.exerciseIndex
        return workout.blocks.filter { $0.exerciseIndex != currentIndex }
    }

    public var totalSetCount: Int { workout.sets.count }

    public var durationMinutes: Int {
        guard let start = workout.startedAt else { return 0 }
        return max(0, Int(Date().timeIntervalSince(start) / 60))
    }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    /// 「上次：60kg × 8, 8, 6」；沒有歷史回 nil。
    public func ghostText(for exerciseId: UUID) -> String? {
        guard let sets = lastPerformances[exerciseId], !sets.isEmpty else { return nil }
        return "上次：\(WeightDisplay.summary(of: sets))"
    }

    /// 照課表時，當前這一組的目標；自由訓練回 nil。
    public var currentTarget: PlannedTargetSet? {
        guard let exerciseId = currentExerciseId else { return nil }
        return blueprint?.target(exerciseId: exerciseId, position: currentBlockSets.count)
    }

    /// 是否照課表訓練。
    public var isFollowingPlan: Bool { blueprint != nil }

    /// 照課表的下一個動作：課表順序中還沒記過、且非當前動作的第一個。全部做過回 nil。
    public var nextPlannedExerciseId: UUID? {
        guard let blueprint else { return nil }
        let recorded = Set(workout.sets.map(\.exerciseId))
        return blueprint.exercises.first {
            $0.exerciseId != currentExerciseId && !recorded.contains($0.exerciseId)
        }?.exerciseId
    }

    /// 下一個課表動作的名稱（給按鈕標題）。
    public var nextPlannedName: String? {
        nextPlannedExerciseId.map { name(for: $0) }
    }

    // MARK: - 動作

    public func onAppear() async {
        do {
            catalog = try await exerciseCatalog.exercises()
        } catch {
            errorMessage = "載入動作庫失敗：\(error.localizedDescription)"
        }
        // 照課表訓練：載入藍圖（含恢復進行中場次的情況）
        if let planWorkoutId = workout.planWorkoutId {
            blueprint = try? await plannedProvider?.blueprint(planWorkoutId: planWorkoutId)
        }
        // 起點：恢復時回到最後一個動作；照課表且尚未開始時跳到課表第一個動作
        if currentExerciseId == nil, let lastBlock = workout.blocks.last {
            await select(exerciseId: lastBlock.exerciseId)
        } else if currentExerciseId == nil, let first = blueprint?.exercises.first {
            await select(exerciseId: first.exerciseId)
        }
    }

    public func select(exerciseId: UUID) async {
        lastRecordedSetId = nil // 換動作 → 先前那組不再可撤銷
        currentExerciseId = exerciseId
        if lastPerformances[exerciseId] == nil {
            let sets = (try? await lastPerformance(exerciseId: exerciseId, excludingWorkout: workout.id)) ?? []
            lastPerformances[exerciseId] = sets
        }
        prefillDraft()
    }

    /// 照課表：跳到課表的下一個動作。
    public func advanceToNextPlanned() async {
        guard let id = nextPlannedExerciseId else { return }
        await select(exerciseId: id)
    }

    public func completeCurrentSet() async {
        let rest = restSecondsForCurrentExercise // 完成這組後的休息（手動調整過則用調整值）
        await appendSet(status: .done)
        // 只有「這個動作還有下一組」才倒數；做完該動作最後一組不休息（該換動作了）
        if let rest, rest > 0, hasNextPlannedSetForCurrentExercise {
            startRest(seconds: rest)
        }
    }

    /// 目前動作完成這組後的休息秒數：優先用訓練中手動調整過的值，否則用課表原定 restSec。
    private var restSecondsForCurrentExercise: Int? {
        guard let id = currentExerciseId else { return currentTarget?.restSec }
        return adjustedRestByExercise[id] ?? currentTarget?.restSec
    }

    /// append 之後，目前動作是否還有下一組課表目標。
    private var hasNextPlannedSetForCurrentExercise: Bool {
        guard let id = currentExerciseId else { return false }
        return blueprint?.target(exerciseId: id, position: currentBlockSets.count) != nil
    }

    public func skipCurrentSet() async {
        await appendSet(status: .skipped)
    }

    /// 復原剛記錄的那一組（撤銷誤按的「完成此組」/「跳過此組」）。
    /// 連帶取消因完成而起的休息倒數與完成卡片，並允許該動作的完成卡片之後重新觸發。
    public func undoLastSet() async {
        guard let id = lastRecordedSetId else { return }
        dismissRest()
        showExerciseComplete = false
        if let exerciseId = currentExerciseId {
            completionShownFor.remove(exerciseId)
        }
        workout.removeSet(id: id)
        lastRecordedSetId = nil
        do {
            try await saveProgress(workout)
        } catch {
            errorMessage = "儲存失敗：\(error.localizedDescription)"
        }
        prefillDraft()
    }

    // MARK: - 動作完成卡片

    /// 剛完成的動作名稱（卡片標題用）。
    public var completedExerciseName: String {
        currentExerciseId.map { name(for: $0) } ?? ""
    }

    /// 完成當前動作後，課表是否全部做完（沒有下一個未做的課表動作）。
    public var isPlanFullyDone: Bool { nextPlannedExerciseId == nil }

    /// 「再做一組」：留在原動作，關掉卡片。
    public func continueSameExercise() {
        showExerciseComplete = false
    }

    public func dismissExerciseComplete() {
        showExerciseComplete = false
    }

    /// append 後檢查：剛好做滿課表組數 → 觸發完成卡片（每動作一次）。
    private func maybeTriggerExerciseComplete() {
        guard let id = currentExerciseId, let blueprint else { return }
        let planned = blueprint.exercises.first { $0.exerciseId == id }?.setCount ?? 0
        guard planned > 0, !completionShownFor.contains(id) else { return }
        if currentBlockSets.count == planned {
            completionShownFor.insert(id)
            showExerciseComplete = true
        }
    }

    // MARK: - 休息倒數

    /// 開始休息倒數。剩餘秒數以「結束時間」為準（背景不失準），並排一則本地通知，
    /// 讓 App 進背景／被切走時，時間到照樣提醒。
    public func startRest(seconds: Int) {
        restTask?.cancel()
        let end = now().addingTimeInterval(TimeInterval(seconds))
        restEndDate = end
        restRemaining = seconds
        restSeconds = seconds
        restExerciseId = currentExerciseId
        restEnded = false
        scheduleRestNotification(at: end)
        startRestTicking()
    }

    /// 訓練中調整休息剩餘秒數（+/- 15 秒）：移動結束時間並重排通知，
    /// 並把調整後的休息長度套用到同一動作的後續各組。
    public func adjustRest(_ delta: Int) {
        guard let end = restEndDate else { return }
        let newEnd = max(now(), end.addingTimeInterval(TimeInterval(delta)))
        restEndDate = newEnd
        scheduleRestNotification(at: newEnd)
        _ = refreshRest()
        // 同步更新該動作後續各組的休息時間（起始長度＋累計調整，不小於 0）
        if let base = restSeconds {
            let updated = max(0, base + delta)
            restSeconds = updated
            if let id = restExerciseId {
                adjustedRestByExercise[id] = updated
            }
        }
    }

    /// 依結束時間重算剩餘秒數（切回前景時呼叫，補上背景經過的時間）。回傳 true＝已結束。
    @discardableResult
    public func refreshRest() -> Bool {
        guard let end = restEndDate else { return true }
        let remaining = Int(ceil(end.timeIntervalSince(now())))
        if remaining <= 0 {
            restRemaining = 0
            restEnded = true
            restEndDate = nil
            restTask?.cancel()
            restTask = nil
            return true
        }
        restRemaining = remaining
        return false
    }

    /// 跳過休息 / 關掉彈窗開始下一組。
    public func dismissRest() {
        restTask?.cancel()
        restTask = nil
        restEndDate = nil
        restRemaining = nil
        restSeconds = nil
        restExerciseId = nil
        restEnded = false
        cancelRestNotification()
    }

    /// 每秒重算一次剩餘秒數（僅為前景時的畫面更新；真正的時間依據是 restEndDate）。
    private func startRestTicking() {
        restTask = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard let self else { return }
                if self.refreshRest() { return }
            }
        }
    }

    private func scheduleRestNotification(at end: Date) {
        pendingRestNotify = Task { [notifications] in
            await notifications.requestAuthorization()
            await notifications.scheduleRestEnd(at: end)
        }
    }

    private func cancelRestNotification() {
        pendingRestNotify = Task { [notifications] in
            await notifications.cancelRestEnd()
        }
    }

    /// 離開（未結束）。回傳 true＝可關閉畫面；空場次直接放棄刪掉。
    public func leave() async {
        dismissRest()
        if workout.sets.isEmpty {
            try? await discardWorkout(id: workout.id)
        }
        isDismissed = true
    }

    public func finish(feeling: Int?, note: String) async {
        dismissRest()
        do {
            try await finishWorkout(workout, overallFeeling: feeling, note: note)
            isDismissed = true
        } catch {
            errorMessage = "儲存失敗：\(error.localizedDescription)"
        }
    }

    public func dismissError() {
        errorMessage = nil
    }

    public func bumpWeight(_ direction: Int) {
        let step = draftWeightUnit == .kg ? 2.5 : 5.0
        draftWeightValue = max(0, draftWeightValue + step * Double(direction))
    }

    public func bumpReps(_ direction: Int) {
        draftReps = max(0, draftReps + direction)
    }

    // MARK: - 私有

    private func appendSet(status: WorkoutSetStatus) async {
        guard let exerciseId = currentExerciseId else { return }
        // 照課表：把當下的目標當快照存入（fromPlanSetId + target_*），脫稿加練則為 nil
        let target = currentTarget
        let newSetId = UUID()
        workout.appendSet(
            id: newSetId,
            exerciseId: exerciseId,
            weight: Weight(value: draftWeightValue, unit: draftWeightUnit),
            reps: draftReps,
            status: status,
            fromPlanSetId: target?.id,
            targetWeight: target?.targetWeight,
            targetReps: target?.targetReps
        )
        lastRecordedSetId = newSetId
        do {
            try await saveProgress(workout) // 每組立即落地，中途被殺不掉資料
        } catch {
            errorMessage = "儲存失敗：\(error.localizedDescription)"
        }
        prefillDraft() // 記完一組後，替下一組預填（照課表會帶下一組目標）
        maybeTriggerExerciseComplete() // 剛做滿課表組數 → 完成卡片
    }

    /// 預填優先序：照課表目標 → 本場同動作上一組 → 上次紀錄對應組 → 預設 20kg × 8。
    private func prefillDraft() {
        guard let exerciseId = currentExerciseId else { return }
        if let target = currentTarget, let weight = target.targetWeight {
            apply(weight: weight, reps: target.targetReps ?? draftReps)
        } else if let last = currentBlockSets.last {
            apply(weight: last.weight, reps: last.reps)
        } else if let history = lastPerformances[exerciseId], let first = history.first {
            apply(weight: first.weight, reps: first.reps)
        } else {
            apply(weight: Weight(value: 20, unit: .kg), reps: 8)
        }
    }

    private func apply(weight: Weight, reps: Int) {
        draftWeightValue = weight.value
        draftWeightUnit = weight.unit
        draftReps = reps
    }
}
