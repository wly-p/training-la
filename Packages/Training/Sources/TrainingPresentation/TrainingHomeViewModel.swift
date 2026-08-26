import Foundation
import Observation
import SharedKernel
import TrainingDomain

/// 「本週」統計（6b／13f 共用）：次數＋累計時長＋7 天完成狀態。
public struct WeekTrainingSummary: Equatable, Sendable {
    public struct Day: Equatable, Sendable, Identifiable {
        public let date: DayDate
        public let isToday: Bool
        public let completed: Bool
        public var id: DayDate { date }
    }

    public let sessionCount: Int
    public let totalMinutes: Int
    /// 本週實際總量（公斤）；13f 左的綠卡要寫「這週已經練了 3 次、9,140 kg」。
    public let totalVolume: Double
    /// 週一到週日。
    public let days: [Day]
}

/// 開練前預覽（13d）：卡片被點開的那一刻試算出來的藍圖，尚未真正「開始」
/// （尚未 `StartWorkout`；循環的話也還沒動游標，見 `PreviewRotationWorkout`）。
public struct PendingStart: Identifiable, Sendable {
    public enum Source: Sendable, Equatable { case plan, rotation(UUID) }
    public let id = UUID()
    public let source: Source
    public let blueprint: PlannedWorkoutBlueprint
    /// 「和上次比」灰卡（14c）；查不到上一場相同主項的紀錄＝nil，卡片不出現。
    public let comparison: LastWorkoutComparison?

    public init(source: Source, blueprint: PlannedWorkoutBlueprint, comparison: LastWorkoutComparison? = nil) {
        self.source = source
        self.blueprint = blueprint
        self.comparison = comparison
    }
}

/// 「和上次比」（14c 底部灰卡）：上次做這個主項是哪天、那場達標幾組、主項這次比上次增減多少。
/// 讓「開始」這個決定有依據，不是鼓勵語。
public struct LastWorkoutComparison: Equatable, Sendable {
    public let date: DayDate
    public let achievedSets: Int
    public let totalSets: Int
    /// 主項（第一個動作）這次目標重量 − 上次最重的一組(done)；nil＝其一算不出，不顯示增減。
    public let mainLiftDeltaKg: Double?

    public init(date: DayDate, achievedSets: Int, totalSets: Int, mainLiftDeltaKg: Double?) {
        self.date = date
        self.achievedSets = achievedSets
        self.totalSets = totalSets
        self.mainLiftDeltaKg = mainLiftDeltaKg
    }
}

/// 訓練首頁「重複上次」列（6b）與「最近練過」清單（13f 右）：一場已完成場次的摘要。
public struct RecentSessionSummary: Equatable, Sendable, Identifiable {
    public let workoutId: UUID
    public let day: DayDate
    /// 範本/排課名；nil＝那場是自由訓練。
    public let name: String?
    public let setCount: Int
    /// 那場練了幾分鐘；算不出（缺起訖時間）＝nil，副標就不寫時長。
    public let minutes: Int?
    /// 照哪個排課做的；nil＝自由訓練，「再練一次」只能開自由訓練。
    public let planWorkoutId: UUID?

    public var id: UUID { workoutId }
}

/// 中斷後恢復（13b）：有未結束場次時，一次性對話框用的摘要。
public struct ResumeSummary: Equatable, Sendable {
    public let workout: Workout
    /// 範本/排課名；nil＝自由訓練。
    public let name: String?
    public let recordedSetCount: Int
    /// 還沒做的組數；nil＝自由訓練（沒有課表組數概念，不知道「剩幾組」）。
    public let remainingSetCount: Int?
    public let elapsedMinutes: Int
    /// 不是今天開始的（隔夜）；決定「結束它」／「繼續」哪個當預設主按鈕。
    public let isOvernight: Bool
}

@MainActor
@Observable
public final class TrainingHomeViewModel {
    /// 有進行中的場次可以繼續。
    public private(set) var resumable: Workout?
    /// `resumable` 非 nil 時的摘要（13b 對話框用）。
    public private(set) var resumeSummary: ResumeSummary?
    /// 今天的排課（照課表訓練的來源）。
    public private(set) var todaysPlan: PlannedWorkoutBlueprint?
    /// 可套用的課表範本（「選範本開始」的來源）。
    public private(set) var templates: [PlannedTemplateSummary] = []
    /// 啟用中的循環課表（每組今天輪到哪張）；可多組並行。
    public private(set) var rotations: [PlannedRotationSummary] = []
    /// 今天剛好是某份長期課表的休息日（13f 左）；只在完全沒有「今天指定」排課時才有意義。
    public private(set) var restDay: RestDayInfo?
    /// 本週次數/時長/7 天完成狀態。
    public private(set) var weekSummary: WeekTrainingSummary?
    /// 最近一場已完成場次（「重複上次」列）；nil＝完全沒練過。
    public private(set) var lastSession: RecentSessionSummary?
    /// 「最近練過」清單（13f 右）：最近幾場已完成場次，最新在前。
    public private(set) var recentSessions: [RecentSessionSummary] = []
    /// 已完成場次快取（最近在前）；供開練前預覽「和上次比」同步試算，不用再打一次 repo。
    private var recentFinished: [Workout] = []
    /// 非 nil → 呈現記錄畫面。
    public var recording: Workout?
    /// 非 nil → 呈現開練前預覽 sheet（13d）。
    public var pendingStart: PendingStart?
    /// 本地化錯誤字串（延後解析，由 View 依 Environment locale 顯示）。
    public private(set) var errorMessage: LocalizedStringResource?

    /// 進行中的計畫數（今天指定 + 隨時可做），Header kicker 用。
    public var activePlanCount: Int {
        (todaysPlan != nil ? 1 : 0) + rotations.count
    }

    /// Header kicker 的日期。View 不要自己 `Date()`——那樣 UI 測試釘死「今天」時
    /// 頁首會跟底下的內容對不上。
    public var todayDate: DayDate { today() }

    private let startWorkout: StartWorkout
    private let resumeWorkout: ResumeWorkout
    private let recentWorkouts: RecentWorkouts?
    private let finishWorkout: FinishWorkout?
    private let discardWorkout: DiscardWorkout?
    private let plannedProvider: (any PlannedWorkoutProvider)?
    private let today: @Sendable () -> DayDate
    private let now: @Sendable () -> Date

    public init(
        startWorkout: StartWorkout,
        resumeWorkout: ResumeWorkout,
        recentWorkouts: RecentWorkouts? = nil,
        finishWorkout: FinishWorkout? = nil,
        discardWorkout: DiscardWorkout? = nil,
        plannedProvider: (any PlannedWorkoutProvider)? = nil,
        today: @escaping @Sendable () -> DayDate = { DayDate(Date()) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.startWorkout = startWorkout
        self.resumeWorkout = resumeWorkout
        self.recentWorkouts = recentWorkouts
        self.finishWorkout = finishWorkout
        self.discardWorkout = discardWorkout
        self.plannedProvider = plannedProvider
        self.today = today
        self.now = now
    }

    public func refresh() async {
        do {
            resumable = try await resumeWorkout()
            await refreshResumeSummary()
            todaysPlan = try await plannedProvider?.todaysPlan()
            templates = try await plannedProvider?.templates() ?? []
            rotations = try await plannedProvider?.activeRotations() ?? []
            // 休息日跟「今天指定」排課互斥，todaysPlan 有值時不用查。
            restDay = todaysPlan == nil ? try await plannedProvider?.activeRestDay() : nil
            try await refreshRecentWorkouts()
            errorMessage = nil
        } catch {
            errorMessage = .training("training.error.loadStatus \(error.localizedDescription)")
        }
    }

    private func refreshResumeSummary() async {
        guard let workout = resumable else {
            resumeSummary = nil
            return
        }
        var name: String?
        var remaining: Int?
        if let planWorkoutId = workout.planWorkoutId,
           let blueprint = try? await plannedProvider?.blueprint(planWorkoutId: planWorkoutId) {
            name = blueprint.name
            let plannedTotal = blueprint.exercises.reduce(0) { $0 + $1.setCount }
            remaining = max(0, plannedTotal - workout.sets.count)
        }
        let elapsedMinutes = workout.startedAt.map { max(0, Int(now().timeIntervalSince($0) / 60)) } ?? 0
        resumeSummary = ResumeSummary(
            workout: workout, name: name, recordedSetCount: workout.sets.count,
            remainingSetCount: remaining, elapsedMinutes: elapsedMinutes,
            isOvernight: workout.day != today()
        )
    }

    private func refreshRecentWorkouts() async throws {
        let finished = try await recentWorkouts?() ?? []
        recentFinished = finished
        weekSummary = Self.weekSummary(from: finished, today: today())
        // 13f 右的「最近練過」只給兩列（設計稿如此）。
        // 自由訓練也要列進來——原本濾掉 planWorkoutId == nil，等於只做自由訓練的人
        // 永遠看不到這個區塊，也就永遠拿不到「再練一次」這條最短的出路。
        // 沒有名字的場次由 View 以本地化的「自由訓練」補上（name 為 nil）。
        var summaries: [RecentSessionSummary] = []
        for workout in finished {
            guard summaries.count < Self.recentSessionLimit else { break }
            var name: String?
            if let planWorkoutId = workout.planWorkoutId {
                name = try await plannedProvider?.blueprint(planWorkoutId: planWorkoutId)?.name
            }
            summaries.append(Self.summary(for: workout, name: name))
        }
        recentSessions = summaries
        if let latest = finished.first {
            var name: String?
            if let planWorkoutId = latest.planWorkoutId {
                name = try await plannedProvider?.blueprint(planWorkoutId: planWorkoutId)?.name
            }
            lastSession = Self.summary(for: latest, name: name)
        } else {
            lastSession = nil
        }
    }

    private static let recentSessionLimit = 2

    private static func summary(for workout: Workout, name: String?) -> RecentSessionSummary {
        var minutes: Int?
        if let start = workout.startedAt, let end = workout.endedAt {
            minutes = max(0, Int(end.timeIntervalSince(start) / 60))
        }
        return RecentSessionSummary(
            workoutId: workout.id, day: workout.day, name: name, setCount: workout.sets.count,
            minutes: minutes, planWorkoutId: workout.planWorkoutId
        )
    }

    /// 一週 7 天，依 `finished`（已完成場次）標記完成日；`today` 落在哪天標 `isToday`。
    ///
    /// `firstWeekday` 用 `Calendar` 的慣例（1=週日…7=週六），預設跟隨裝置的**地區**設定。
    /// 這裡刻意讀地區而不是 app 的語言設定——「一週從哪天開始」是地區慣例
    /// （美國從週日、台灣從週一），跟介面顯示哪種語言無關。
    /// 原本寫死 `(weekdayNumber + 5) % 7`＝永遠週一起算，對週日起算的地區會整排偏一天。
    static func weekSummary(
        from finished: [Workout],
        today: DayDate,
        firstWeekday: Int = Calendar.current.firstWeekday
    ) -> WeekTrainingSummary {
        let daysSinceStart = (today.weekdayNumber - firstWeekday + 7) % 7
        let weekStart = today.adding(days: -daysSinceStart)
        let weekDates = (0..<7).map { weekStart.adding(days: $0) }
        let doneDates = Set(finished.map(\.day)).intersection(weekDates)
        let thisWeek = finished.filter { weekDates.contains($0.day) }
        let totalMinutes = thisWeek.reduce(0) { sum, workout in
            guard let start = workout.startedAt, let end = workout.endedAt else { return sum }
            return sum + max(0, Int(end.timeIntervalSince(start) / 60))
        }
        let totalVolume = thisWeek.reduce(0.0) { $0 + FinishSummaryFormatting.totalVolume($1.sets) }
        let days = weekDates.map { date in
            WeekTrainingSummary.Day(date: date, isToday: date == today, completed: doneDates.contains(date))
        }
        return WeekTrainingSummary(
            sessionCount: thisWeek.count, totalMinutes: totalMinutes, totalVolume: totalVolume, days: days
        )
    }

    /// 自由訓練（不帶課表）。
    public func startFree() async {
        await start(blueprint: nil)
    }

    /// 重複上次：開一場新的自由訓練（沿用「上次」提示的既有機制，選動作時會自動帶上次紀錄預填）。
    public func startRepeatingLast() async {
        await start(blueprint: nil)
    }

    /// 「最近練過 · 再練一次」（13f 右）：照那場當初的排課藍圖再開一場；
    /// 藍圖查不回來（排課被刪了）就退成自由訓練，不讓按鈕變成死的。
    public func startRepeating(_ session: RecentSessionSummary) async {
        guard let planWorkoutId = session.planWorkoutId else {
            await start(blueprint: nil)
            return
        }
        do {
            let blueprint = try await plannedProvider?.blueprint(planWorkoutId: planWorkoutId)
            await start(blueprint: blueprint)
        } catch {
            errorMessage = .training("training.error.startFailed \(error.localizedDescription)")
        }
    }

    /// 「把明天的腿日挪到今天」（13f 左）：對調今天與下一個訓練日，然後重新整理 —— 挪完今天就
    /// 有排課了，畫面自然從休息日狀態切成 6b。
    public func moveNextWorkoutToToday() async {
        do {
            try await plannedProvider?.moveNextWorkoutToToday()
            await refresh()
        } catch {
            errorMessage = .training("training.error.saveFailed \(error.localizedDescription)")
        }
    }

    /// 照今天的課表開始。
    public func startFromPlan() async {
        await start(blueprint: todaysPlan)
    }

    /// 選一個課表範本開始：實例化成當日排課，再照其藍圖訓練。
    public func startFromTemplate(id: UUID) async {
        do {
            guard let blueprint = try await plannedProvider?.instantiate(templateId: id) else { return }
            await start(blueprint: blueprint)
        } catch {
            errorMessage = .training("training.error.startFailed \(error.localizedDescription)")
        }
    }

    /// 開始某組循環今天輪到的 workout：建立當日排課、游標前進，照其藍圖訓練。
    public func startFromRotation(id: UUID) async {
        do {
            guard let blueprint = try await plannedProvider?.startRotation(id: id) else { return }
            await start(blueprint: blueprint)
        } catch {
            errorMessage = .training("training.error.startFailed \(error.localizedDescription)")
        }
    }

    public func resume() {
        recording = resumable
    }

    /// 「結束它，存成之前的紀錄」（13b）：直接標記完成，不進記錄畫面。時間戳只能用「現在」——
    /// WorkoutSet 目前沒有逐組時間戳，沒有『最後一組實際記錄時間』這個資料可用，
    /// 這是唯一不編造歷史時間的誠實做法。
    public func endResumableNow() async {
        guard let workout = resumable, let finishWorkout else { return }
        do {
            _ = try await finishWorkout(workout, overallFeeling: nil, note: nil)
            await refresh()
        } catch {
            errorMessage = .training("training.error.saveFailed \(error.localizedDescription)")
        }
    }

    /// 「捨棄整場」（13b）：整場（含已記錄的組）直接刪掉；呼叫端要先二次確認過。
    public func discardResumable() async {
        guard let workout = resumable, let discardWorkout else { return }
        do {
            try await discardWorkout(id: workout.id)
            await refresh()
        } catch {
            errorMessage = .training("training.error.saveFailed \(error.localizedDescription)")
        }
    }

    // MARK: - 開練前預覽（13d）

    /// 點「今天指定」卡：today's plan 已經材料化好了，直接拿現成的藍圖預覽，不用再問一次 Plan。
    public func previewPlan() {
        guard let plan = todaysPlan else { return }
        pendingStart = PendingStart(source: .plan, blueprint: plan,
                                    comparison: Self.lastComparison(for: plan, among: recentFinished))
    }

    /// 點「隨時可做」卡：用不落地、不動游標的 `previewRotation` 試算，跟「開始循環」分開。
    public func previewRotation(id: UUID) async {
        do {
            guard let blueprint = try await plannedProvider?.previewRotation(id: id) else { return }
            pendingStart = PendingStart(source: .rotation(id), blueprint: blueprint,
                                        comparison: Self.lastComparison(for: blueprint, among: recentFinished))
        } catch {
            errorMessage = .training("training.error.loadStatus \(error.localizedDescription)")
        }
    }

    /// 「和上次比」試算（14c）：在已完成場次裡找最近一場「有做到這個主項（第一個動作）」的，
    /// 回它的日期、達標組數，以及主項這次目標重量 − 上次最重一組(done) 的增減。
    /// 純函式（吃現成資料），方便單元測試；不碰實例狀態，標 nonisolated 讓測試/非主執行緒也能呼叫。
    nonisolated static func lastComparison(for blueprint: PlannedWorkoutBlueprint, among finished: [Workout]) -> LastWorkoutComparison? {
        guard let mainExerciseId = blueprint.exercises.first?.exerciseId,
              let last = finished.first(where: { $0.blocks.contains { $0.exerciseId == mainExerciseId } })
        else { return nil }
        let counts = FinishSummaryFormatting.achievedSetCount(last.sets)
        // delta 的單位是公斤（見 mainLiftDeltaKg），兩邊都先換算再相減；
        // 取最重那組也用 Weight 比較，拿 .value 比在混單位時會挑錯組。
        let thisWeight = blueprint.targets.first { $0.exerciseId == mainExerciseId }?.targetWeight?.kilograms
        // 熱身組排除：拿熱身的 20kg 當「上次」會算出一個假的大幅進步。
        let lastWeight = last.blocks.first { $0.exerciseId == mainExerciseId }?
            .sets.filter { $0.status == .done && !$0.isWarmup }.map(\.weight).max()?.kilograms
        let delta: Double? = if let thisWeight, let lastWeight { thisWeight - lastWeight } else { nil }
        return LastWorkoutComparison(date: last.day, achievedSets: counts.achieved,
                                     totalSets: counts.total, mainLiftDeltaKg: delta)
    }

    public func dismissPendingStart() {
        pendingStart = nil
    }

    /// 預覽 sheet 按「開始訓練」：這一刻才真正落地（循環的游標也是這時才動）。
    public func confirmPendingStart() async {
        guard let pending = pendingStart else { return }
        pendingStart = nil
        switch pending.source {
        case .plan:
            await startFromPlan()
        case .rotation(let id):
            await startFromRotation(id: id)
        }
    }

    public func dismissError() { errorMessage = nil }

    private func start(blueprint: PlannedWorkoutBlueprint?) async {
        do {
            recording = try await startWorkout(blueprint: blueprint)
        } catch {
            errorMessage = .training("training.error.startFailed \(error.localizedDescription)")
        }
    }
}
