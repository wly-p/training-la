import Foundation
import Observation
import RemindersDomain
import SharedKernel
import TrainingDomain

/// 訓練中「接下來」清單的一列（尚未做的課表動作）。
public struct UpcomingExercise: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
}

@MainActor
@Observable
public final class ActiveWorkoutViewModel {
    public private(set) var workout: Workout
    public private(set) var catalog: [CatalogExercise] = []
    public private(set) var lastPerformances: [UUID: [WorkoutSet]] = [:]
    public private(set) var currentExerciseId: UUID?
    /// 本地化錯誤字串（延後解析，由 View 依 Environment locale 顯示）。
    public private(set) var errorMessage: LocalizedStringResource?
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
    /// 休息結束提醒（背景通知＋前景聲音/震動；彈窗依偏好由 View 決定）。
    private let reminder: any RestEndReminding

    public init(
        workout: Workout,
        saveProgress: SaveWorkoutProgress,
        finishWorkout: FinishWorkout,
        discardWorkout: DiscardWorkout,
        lastPerformance: LastPerformance,
        exerciseCatalog: any ExerciseCatalog,
        plannedProvider: (any PlannedWorkoutProvider)? = nil,
        reminder: any RestEndReminding = NoopRestEndReminding(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.workout = workout
        self.saveProgress = saveProgress
        self.finishWorkout = finishWorkout
        self.discardWorkout = discardWorkout
        self.lastPerformance = lastPerformance
        self.exerciseCatalog = exerciseCatalog
        self.plannedProvider = plannedProvider
        self.reminder = reminder
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

    /// 上次同動作的組摘要「60kg × 8, 8, 6」；沒有歷史回 nil。「上次：」前綴由 View 本地化組。
    public func lastSummary(for exerciseId: UUID) -> String? {
        guard let sets = lastPerformances[exerciseId], !sets.isEmpty else { return nil }
        return WeightDisplay.summary(of: sets)
    }

    /// 照課表時，當前這一組的目標；自由訓練回 nil。
    public var currentTarget: PlannedTargetSet? {
        guard let exerciseId = currentExerciseId else { return nil }
        return blueprint?.target(exerciseId: exerciseId, position: currentBlockSets.count)
    }

    /// 是否照課表訓練。
    public var isFollowingPlan: Bool { blueprint != nil }

    /// 本場課表動作順序：訓練中可拖拉調整（session 內有效，不落地回課表範本/排課）。
    /// nil＝沿用課表原順序。
    private var reorderedPlan: [UUID]?
    private var plannedOrderIds: [UUID] {
        reorderedPlan ?? blueprint?.exercises.map(\.exerciseId) ?? []
    }

    /// 照課表的下一個動作：（可調整後）順序中還沒記過、且非當前動作的第一個。全部做過回 nil。
    public var nextPlannedExerciseId: UUID? {
        guard blueprint != nil else { return nil }
        let recorded = Set(workout.sets.map(\.exerciseId))
        return plannedOrderIds.first { $0 != currentExerciseId && !recorded.contains($0) }
    }

    /// 下一個課表動作的名稱（給按鈕標題）。
    public var nextPlannedName: String? {
        nextPlannedExerciseId.map { name(for: $0) }
    }

    /// 「接下來」：尚未做、且非當前動作的課表動作，照（可拖拉調整後的）順序。
    public var upcomingExercises: [UpcomingExercise] {
        guard blueprint != nil else { return [] }
        let recorded = Set(workout.sets.map(\.exerciseId))
        return plannedOrderIds
            .filter { $0 != currentExerciseId && !recorded.contains($0) }
            .map { UpcomingExercise(id: $0, name: name(for: $0)) }
    }

    /// 訓練中拖拉調整「接下來」的順序：只重排未做動作彼此的相對位置，
    /// 已做／當前動作在序列中的位置不動。session 內有效。
    public func moveUpcoming(fromOffsets source: IndexSet, toOffset destination: Int) {
        let recorded = Set(workout.sets.map(\.exerciseId))
        var order = plannedOrderIds
        let slots = order.indices.filter { order[$0] != currentExerciseId && !recorded.contains(order[$0]) }
        var ids = slots.map { order[$0] }
        Self.moveElements(&ids, fromOffsets: source, toOffset: destination)
        for (i, slot) in slots.enumerated() { order[slot] = ids[i] }
        reorderedPlan = order
    }

    /// 複製 SwiftUI Array.move(fromOffsets:toOffset:) 語意（VM 不引 SwiftUI）。
    private static func moveElements<T>(_ array: inout [T], fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().map { array[$0] }
        for index in source.sorted(by: >) { array.remove(at: index) }
        let adjusted = destination - source.filter { $0 < destination }.count
        array.insert(contentsOf: moving, at: adjusted)
    }

    // MARK: - 動作

    public func onAppear() async {
        do {
            catalog = try await exerciseCatalog.exercises()
        } catch {
            errorMessage = .training("training.error.loadExercises \(error.localizedDescription)")
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
        let rest = restSecondsForCurrentExercise // 完成這組後的休息（手動設過/調整過則用該值）
        await appendSet(status: .done)
        if let rest, rest > 0, shouldRestAfterCurrentSet {
            startRest(seconds: rest)
        }
    }

    /// 目前動作完成這組後的休息秒數：優先用訓練中手動設定/調整過的值，否則用課表原定 restSec。
    /// 自由訓練沒有課表 restSec，只有手動設過才有值。
    private var restSecondsForCurrentExercise: Int? {
        guard let id = currentExerciseId else { return currentTarget?.restSec }
        return adjustedRestByExercise[id] ?? currentTarget?.restSec
    }

    /// 完成這組後是否該起休息倒數。
    /// 照課表：只有「這個動作還有下一組」才休息（做完最後一組該換動作了）。
    /// 自由訓練：沒有「最後一組」的概念，只要有休息秒數就起（沒設過則 rest 為 nil，不會走到這）。
    private var shouldRestAfterCurrentSet: Bool {
        guard isFollowingPlan else { return true }
        return hasNextPlannedSetForCurrentExercise
    }

    /// append 之後，目前動作是否還有下一組課表目標。
    private var hasNextPlannedSetForCurrentExercise: Bool {
        guard let id = currentExerciseId else { return false }
        return blueprint?.target(exerciseId: id, position: currentBlockSets.count) != nil
    }

    /// 使用者手動設定休息秒數（計時器選單選預設值）：記為該動作的休息偏好並開始倒數，
    /// 之後同動作各組完成時會自動沿用這個秒數。
    public func startManualRest(seconds: Int) {
        if let id = currentExerciseId {
            adjustedRestByExercise[id] = seconds
        }
        startRest(seconds: seconds)
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
            errorMessage = .training("training.error.saveFailed \(error.localizedDescription)")
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
        scheduleReminder(at: end)
        startRestTicking()
    }

    /// 訓練中調整休息剩餘秒數（+/- 15 秒）：移動結束時間並重排通知，
    /// 並把調整後的休息長度套用到同一動作的後續各組。
    public func adjustRest(_ delta: Int) {
        guard let end = restEndDate else { return }
        let newEnd = max(now(), end.addingTimeInterval(TimeInterval(delta)))
        restEndDate = newEnd
        scheduleReminder(at: newEnd)
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
        cancelReminder()
    }

    /// 前景是否顯示「休息結束」彈窗（依使用者提醒偏好）。
    public var showsRestEndedAlert: Bool { restEnded && reminder.preference.popup }

    /// App 進背景：停掉前景 ticking（保留結束時間）。避免回前景時補跑「到點前景提醒」，
    /// 與背景已投遞的通知重複發聲。
    public func suspendRestTicking() {
        restTask?.cancel()
        restTask = nil
    }

    /// App 回前景：補算剩餘秒數；若還在休息就重啟 ticking。
    public func enterForeground() {
        guard restEndDate != nil else { return }
        if !refreshRest() { startRestTicking() }
    }

    /// 每秒重算一次剩餘秒數（僅前景；背景由 suspendRestTicking 停掉）。
    /// 於前景到點歸零時觸發前景提醒（聲音/震動）。
    private func startRestTicking() {
        restTask = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard let self else { return }
                if self.refreshRest() {
                    self.deliverForegroundReminder()
                    return
                }
            }
        }
    }

    private func scheduleReminder(at end: Date) {
        pendingRestNotify = Task { [reminder] in
            await reminder.schedule(at: end)
        }
    }

    private func cancelReminder() {
        pendingRestNotify = Task { [reminder] in
            await reminder.cancel()
        }
    }

    private func deliverForegroundReminder() {
        Task { [reminder] in await reminder.deliverForeground() }
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
            errorMessage = .training("training.error.saveFailed \(error.localizedDescription)")
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
            errorMessage = .training("training.error.saveFailed \(error.localizedDescription)")
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
