import Foundation
import Observation
import RemindersDomain
import SharedKernel
import TrainingDomain

/// 訓練中「本場動作」清單的一列：涵蓋課表動作與臨場加練，各帶狀態。
public struct SessionExercise: Identifiable, Equatable, Sendable {
    public enum Status: Sendable, Equatable { case done, current, partial, upcoming }
    public let id: UUID          // exerciseId
    public let name: String
    public let status: Status
    public let doneSetCount: Int
    public let plannedSetCount: Int   // 0＝非課表動作（臨場加練）
    public var isCurrent: Bool { status == .current }
    public var isPlanned: Bool { plannedSetCount > 0 }
}

/// 「下一組」預覽：讓使用者不用翻課表就知道正在做的這組之後要做什麼。
public enum NextSetPreview: Equatable, Sendable {
    /// 還有下一組：同動作下一組（isNextExercise=false），或當前是最後一組時的下一個動作（true）。
    case upcoming(exerciseName: String, target: PlannedTargetSet?, isNextExercise: Bool)
    /// 整場最後一組，做完就結束。
    case lastSet
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
    /// 目前這段休息的「完整秒數」（起始設定值，非剩餘）；供調整時換算並套用到後續組，
    /// 也給 13c 全螢幕的進度條算比例（`restRemaining / restTotalSeconds`）用。
    private var restSeconds: Int?
    public var restTotalSeconds: Int? { restSeconds }
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
    /// 草稿的單位。新的一組用使用者的預設單位；載入既有紀錄時沿用那筆自己的單位
    /// （見 `apply(weight:reps:)`）——換算只發生在比較與顯示，儲存不做正規化。
    public var draftWeightUnit: WeightUnit
    public var draftReps: Int = 8
    /// 使用者的重量級距偏好：± 快捷一次動多少、選擇器滾輪每格差多少。
    /// 每次讀取都問偏好，不在 init 快取——否則訓練途中去設定改級距，回來這場不會生效
    /// （這個 view model 活在整場訓練期間）。UserDefaults 讀取很便宜。
    public var weightStep: Double { preferences.loadWeightStep() }
    /// 使用者的休息時間級距偏好（秒）：休息中 ± 按鈕一次動多少。同上，即時讀取。
    public var restStep: Int { preferences.loadRestStep() }

    private let saveProgress: SaveWorkoutProgress
    private let finishWorkout: FinishWorkout
    private let discardWorkout: DiscardWorkout
    private let lastPerformance: LastPerformance
    private let detectPersonalRecords: DetectPersonalRecords?
    private let exerciseCatalog: any ExerciseCatalog
    private let plannedProvider: (any PlannedWorkoutProvider)?
    /// 目前時間來源（可注入以測試背景經過時間）。
    private let now: () -> Date
    /// 休息結束提醒（背景通知＋前景聲音/震動；彈窗依偏好由 View 決定）。
    private let reminder: any RestEndReminding
    /// 訓練偏好（重量／休息級距）。存 store 本身而非載入後的值，才能即時反映設定變更。
    private let preferences: any TrainingPreferenceStoring

    public init(
        workout: Workout,
        saveProgress: SaveWorkoutProgress,
        finishWorkout: FinishWorkout,
        discardWorkout: DiscardWorkout,
        lastPerformance: LastPerformance,
        detectPersonalRecords: DetectPersonalRecords? = nil,
        exerciseCatalog: any ExerciseCatalog,
        plannedProvider: (any PlannedWorkoutProvider)? = nil,
        reminder: any RestEndReminding = NoopRestEndReminding(),
        weightUnitStore: any WeightUnitPreferenceStoring = InMemoryWeightUnitStore(),
        preferences: any TrainingPreferenceStoring = InMemoryTrainingPreferenceStore(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.workout = workout
        self.saveProgress = saveProgress
        self.finishWorkout = finishWorkout
        self.discardWorkout = discardWorkout
        self.lastPerformance = lastPerformance
        self.detectPersonalRecords = detectPersonalRecords
        self.exerciseCatalog = exerciseCatalog
        self.plannedProvider = plannedProvider
        self.reminder = reminder
        self.draftWeightUnit = weightUnitStore.load()
        self.preferences = preferences
        self.now = now
    }

    // MARK: - 衍生狀態

    public var currentBlockSets: [WorkoutSet] {
        guard let id = currentExerciseId else { return [] }
        return workout.blocks.last { $0.exerciseId == id }?.sets ?? []
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

    /// 組表一列（3b+11c）：已完成／進行中／未做，各自帶目標＋實際。
    public struct SetTableRow: Identifiable, Equatable, Sendable {
        public enum Status: Equatable, Sendable { case done, current, upcoming }
        public let setIndex: Int
        public let target: PlannedTargetSet?
        public let actual: WorkoutSet?
        public let status: Status
        public var id: Int { setIndex }
    }

    /// 組表：已完成的組（帶目標快照）→ 正在輸入的這一組（current）→ 照課表還沒做到的組（upcoming，
    /// 自由訓練沒有課表組數就不會有這段）。
    public var setTableRows: [SetTableRow] {
        guard let exerciseId = currentExerciseId else { return [] }
        var rows: [SetTableRow] = currentBlockSets.map { set in
            SetTableRow(
                setIndex: set.setIndex,
                target: blueprint?.target(exerciseId: exerciseId, position: set.setIndex),
                actual: set, status: .done
            )
        }
        let currentPosition = currentBlockSets.count
        rows.append(SetTableRow(
            setIndex: currentPosition,
            target: blueprint?.target(exerciseId: exerciseId, position: currentPosition),
            actual: nil, status: .current
        ))
        if let plannedCount = blueprint?.exercises.first(where: { $0.exerciseId == exerciseId })?.setCount,
           currentPosition + 1 < plannedCount {
            for position in (currentPosition + 1)..<plannedCount {
                rows.append(SetTableRow(
                    setIndex: position,
                    target: blueprint?.target(exerciseId: exerciseId, position: position),
                    actual: nil, status: .upcoming
                ))
            }
        }
        return rows
    }

    /// 是否照課表訓練。
    public var isFollowingPlan: Bool { blueprint != nil }

    /// 本場課表動作順序：訓練中可拖拉調整（session 內有效，不落地回課表範本/排課）。
    /// nil＝沿用課表原順序。
    private var reorderedPlan: [UUID]?
    private var plannedOrderIds: [UUID] {
        reorderedPlan ?? blueprint?.exercises.map(\.exerciseId) ?? []
    }

    /// 各動作已記錄組數（done／skipped 都算「已處理一組」）。
    private var doneSetCounts: [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for set in workout.sets { counts[set.exerciseId, default: 0] += 1 }
        return counts
    }

    /// 各課表動作的目標組數（課表原定，未套 13e 的本場覆寫）。
    private var plannedSetCounts: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: (blueprint?.exercises ?? []).map { ($0.exerciseId, $0.setCount) })
    }

    /// 中途改課（13e）「再加一組／少做一組」的本場覆寫；只在這個 session 記憶體內有效，
    /// 不落地回課表範本／排課——跟 `reorderedPlan` 同一個既定模式（訓練中的臨時調整本來就
    /// 不該動範本，見 91-weight-model.md §5／01-training.md「臨時調整不污染範本」）。
    private var setCountOverrides: [UUID: Int] = [:]
    /// 中途改課「從這場移除」；只允許還沒開始（沒有任何記錄）的動作，同樣只在本場有效。
    private var removedExerciseIds: Set<UUID> = []

    /// 這個動作本場實際的目標組數：有 13e 覆寫就用覆寫值，否則沿用課表原定。
    private func effectivePlannedSetCount(_ exerciseId: UUID) -> Int {
        setCountOverrides[exerciseId] ?? plannedSetCounts[exerciseId] ?? 0
    }

    /// 課表動作是否「做滿」（做一半不算做完）。
    private func isPlannedExerciseFullyDone(_ id: UUID) -> Bool {
        let planned = effectivePlannedSetCount(id)
        guard planned > 0 else { return false }
        return (doneSetCounts[id] ?? 0) >= planned
    }

    /// 照課表的下一個動作：（可調整後）順序中「還沒做滿」且非當前動作的第一個。全部做滿回 nil。
    /// 用「做滿」而非「有紀錄」判斷——否則做一半就跳走的動作會被當成已完成，導致提早跳訓練結束。
    public var nextPlannedExerciseId: UUID? {
        guard blueprint != nil else { return nil }
        return plannedOrderIds.first { $0 != currentExerciseId && !isPlannedExerciseFullyDone($0) }
    }

    /// 下一個課表動作的名稱（給按鈕標題）。
    public var nextPlannedName: String? {
        nextPlannedExerciseId.map { name(for: $0) }
    }

    /// 正在輸入這組之後的「下一組」預覽（照課表訓練用；自由訓練回 nil）。
    public var nextSetPreview: NextSetPreview? {
        guard let blueprint, let currentId = currentExerciseId else { return nil }
        let currentPos = currentBlockSets.count   // 正在輸入的這組的位置（0-based）
        // 同動作還有下一組
        if let next = blueprint.target(exerciseId: currentId, position: currentPos + 1) {
            return .upcoming(exerciseName: name(for: currentId), target: next, isNextExercise: false)
        }
        // 當前是這動作最後一組 → 下一個動作的下一組（其未做滿的第一組）
        if let nextId = nextPlannedExerciseId {
            let pos = doneSetCounts[nextId] ?? 0
            return .upcoming(exerciseName: name(for: nextId),
                             target: blueprint.target(exerciseId: nextId, position: pos),
                             isNextExercise: true)
        }
        // 沒有下一組了 → 整場最後一組
        return .lastSet
    }

    /// 本場動作完整序列：課表順序（可拖拉調整後）→ 其後接臨場加練 → 確保當前動作在內。
    /// 每列帶狀態（已完成／進行中／做一半／未開始）＋已做/課表組數，供訓練畫面一份清單呈現。
    public var sessionSequence: [SessionExercise] {
        let doneCounts = doneSetCounts

        var ids = plannedOrderIds.filter { !removedExerciseIds.contains($0) }
        for block in workout.blocks where !ids.contains(block.exerciseId) { ids.append(block.exerciseId) }
        if let current = currentExerciseId, !ids.contains(current) { ids.append(current) }

        return ids.map { id in
            let done = doneCounts[id] ?? 0
            let planned = effectivePlannedSetCount(id)
            let status: SessionExercise.Status
            if id == currentExerciseId {
                status = .current
            } else if planned > 0 {
                status = done >= planned ? .done : (done > 0 ? .partial : .upcoming)
            } else {
                status = done > 0 ? .done : .upcoming   // 加練：有紀錄即視為已做
            }
            return SessionExercise(id: id, name: name(for: id), status: status,
                                   doneSetCount: done, plannedSetCount: planned)
        }
    }

    /// 訓練中拖拉調整順序：以完整序列的新排列，取出課表動作的新相對順序存起來
    /// （影響 nextPlanned 與清單順序；已做/當前只是視覺上在清單裡）。session 內有效。
    public func reorderSession(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ids = sessionSequence.map(\.id)
        Self.moveElements(&ids, fromOffsets: source, toOffset: destination)
        let plannedSet = Set(blueprint?.exercises.map(\.exerciseId) ?? [])
        reorderedPlan = ids.filter { plannedSet.contains($0) }
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

    // MARK: - 中途改課（13e）：長按本場動作列的五個操作，都只影響今天這一場，不動範本。

    /// 「再加一組」：目標組數 +1（只影響還沒做的部分）。新加的那組沒有課表目標，
    /// 組表「目標」欄自然顯示待填，使用者自己輸入——不猜一個數字塞進去。
    public func addPlannedSet(for exerciseId: UUID) {
        setCountOverrides[exerciseId] = effectivePlannedSetCount(exerciseId) + 1
    }

    /// 「少做一組」：目標組數 −1，但不會低於已經做掉的組數，避免跟已記錄的組矛盾
    /// （3 組已做 3 組時，這個操作沒有效果）。
    public func removePlannedSet(for exerciseId: UUID) {
        let done = doneSetCounts[exerciseId] ?? 0
        setCountOverrides[exerciseId] = max(done, effectivePlannedSetCount(exerciseId) - 1)
    }

    /// 「跳過這個動作」：還沒做的組依序記為 `.skipped`，直到補滿目標組數——記為「未做」，
    /// 仍留在這場紀錄裡（跟「從這場移除」的差別）。重用既有 `select`/`skipCurrentSet`，
    /// 不另寫一套記錄邏輯，資料一致性照舊由 `appendSet` 保證。
    public func skipRemainingSets(for exerciseId: UUID) async {
        if currentExerciseId != exerciseId {
            await select(exerciseId: exerciseId)
        }
        while currentBlockSets.count < effectivePlannedSetCount(exerciseId) {
            await skipCurrentSet()
        }
    }

    /// 「換一個動作」：先把這個動作剩下沒做的組跳過（已完成的組保留在原動作名下），
    /// 再選新動作接著做——用「跳過」＋「像臨時加練一樣開始新動作」組合出「換動作」的效果，
    /// 不用另外設計「新動作沿用舊目標重量」這種容易出錯的搬遷邏輯；新動作走既有的
    /// 「上次紀錄」預填，跟平常加練一致。
    public func replaceExercise(_ exerciseId: UUID, with newExerciseId: UUID) async {
        await skipRemainingSets(for: exerciseId)
        await select(exerciseId: newExerciseId)
    }

    /// 「從這場移除」：只允許還沒開始（沒有任何記錄）的動作；不寫入任何 WorkoutSet——跟
    /// 「跳過」不同，跳過會留下 skipped 紀錄，移除則什麼都不留。只在本場 session 記憶體內
    /// 有效：離開又恢復這場時，這個動作會依原課表重新出現（跟 `reorderedPlan` 同一個既定取捨）。
    public func removeFromSession(exerciseId: UUID) {
        guard (doneSetCounts[exerciseId] ?? 0) == 0 else { return }
        removedExerciseIds.insert(exerciseId)
        if currentExerciseId == exerciseId {
            currentExerciseId = nil
        }
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
        guard let id = currentExerciseId else { return }
        let planned = effectivePlannedSetCount(id)
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

    /// 訓練中調整休息剩餘秒數（`delta` 由呼叫端帶入使用者的級距偏好 `restStep`）：
    /// 移動結束時間並重排通知，並把調整後的休息長度套用到同一動作的後續各組。
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

    // 排程／取消一律串接在前一個動作之後，保證依呼叫順序、彼此不重疊執行。
    // 否則快速連續動作（休息中又完成一組、早結束又換組、連點 +/-）會 spawn 多個並行 Task，
    // 底層通知中心的 remove/add 交錯，舊排程沒被蓋掉 → 重複投遞（bug③）。
    private func scheduleReminder(at end: Date) {
        let previous = pendingRestNotify
        pendingRestNotify = Task { [reminder] in
            _ = await previous?.value
            await reminder.schedule(at: end)
        }
    }

    private func cancelReminder() {
        let previous = pendingRestNotify
        pendingRestNotify = Task { [reminder] in
            _ = await previous?.value
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

    /// 完成摘要（13a）用：查這場目前為止的 PR。可以在「結束訓練」sheet 開啟、正式送出
    /// 「完成並存檔」之前呼叫——不要求 workout 已經 finish/save。
    public func detectPersonalRecordsForThisSession() async -> [ExercisePRAnnouncement] {
        guard let detectPersonalRecords else { return [] }
        return (try? await detectPersonalRecords(workout)) ?? []
    }

    /// 「捨棄這場」（13a）：整場（含已記錄的組）直接刪掉；跟 `leave()`「空場次才自動丟」不同——
    /// 這裡是使用者主動放棄已經有紀錄的一場，呼叫端要先二次確認過。
    public func discardCurrentWorkout() async {
        dismissRest()
        do {
            try await discardWorkout(id: workout.id)
            isDismissed = true
        } catch {
            errorMessage = .training("training.error.saveFailed \(error.localizedDescription)")
        }
    }

    public func dismissError() {
        errorMessage = nil
    }

    public func bumpWeight(_ direction: Int) {
        // 從現值加減，不吸附到級距網格：按鈕標「+1」就該動 1，
        // 課表預填的目標常常本來就不在使用者自訂級距的格子上。
        draftWeightValue = WeightRange.clamped(
            draftWeightValue + weightStep * Double(direction), unit: draftWeightUnit
        )
    }

    public func bumpReps(_ direction: Int) {
        draftReps = max(0, draftReps + direction)
    }

    /// 快捷「同上組」：把草稿設回本場這個動作上一組記錄的值；沒有上一組時無效。
    public func applyLastSetValues() {
        guard let last = currentBlockSets.last else { return }
        apply(weight: last.weight, reps: last.reps)
    }

    /// 快捷「回到目標」：把草稿重設回這組的課表目標；沒有目標時無效。
    public func resetToTarget() {
        guard let target = currentTarget, let weight = target.targetWeight else { return }
        apply(weight: weight, reps: target.targetReps ?? draftReps)
    }

    /// 草稿是否已經偏離目標——決定第三顆快捷鍵顯示「同上組」還是「回到目標」（11c）。
    public var isDraftModifiedFromTarget: Bool {
        guard let target = currentTarget, let weight = target.targetWeight else { return false }
        // 草稿與目標可能不同單位，要組成 Weight 比而不是比裸數字。
        let draft = Weight(value: draftWeightValue, unit: draftWeightUnit)
        return draft != weight || (target.targetReps.map { $0 != draftReps } ?? false)
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
