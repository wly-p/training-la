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
}

/// 訓練首頁「重複上次」列：最近一場已完成場次的摘要。
public struct RecentSessionSummary: Equatable, Sendable {
    public let workoutId: UUID
    public let day: DayDate
    /// 範本/排課名；nil＝那場是自由訓練。
    public let name: String?
    public let setCount: Int
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
        weekSummary = Self.weekSummary(from: finished, today: today())
        if let latest = finished.first {
            var name: String?
            if let planWorkoutId = latest.planWorkoutId {
                name = try await plannedProvider?.blueprint(planWorkoutId: planWorkoutId)?.name
            }
            lastSession = RecentSessionSummary(workoutId: latest.id, day: latest.day, name: name, setCount: latest.sets.count)
        } else {
            lastSession = nil
        }
    }

    /// 週一到週日 7 天，依 `finished`（已完成場次）標記完成日；`today` 落在哪天標 `isToday`。
    static func weekSummary(from finished: [Workout], today: DayDate) -> WeekTrainingSummary {
        let daysSinceMonday = (today.weekdayNumber + 5) % 7
        let monday = today.adding(days: -daysSinceMonday)
        let weekDates = (0..<7).map { monday.adding(days: $0) }
        let doneDates = Set(finished.map(\.day)).intersection(weekDates)
        let thisWeek = finished.filter { weekDates.contains($0.day) }
        let totalMinutes = thisWeek.reduce(0) { sum, workout in
            guard let start = workout.startedAt, let end = workout.endedAt else { return sum }
            return sum + max(0, Int(end.timeIntervalSince(start) / 60))
        }
        let days = weekDates.map { date in
            WeekTrainingSummary.Day(date: date, isToday: date == today, completed: doneDates.contains(date))
        }
        return WeekTrainingSummary(sessionCount: thisWeek.count, totalMinutes: totalMinutes, days: days)
    }

    /// 自由訓練（不帶課表）。
    public func startFree() async {
        await start(blueprint: nil)
    }

    /// 重複上次：開一場新的自由訓練（沿用「上次」提示的既有機制，選動作時會自動帶上次紀錄預填）。
    public func startRepeatingLast() async {
        await start(blueprint: nil)
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
        pendingStart = PendingStart(source: .plan, blueprint: plan)
    }

    /// 點「隨時可做」卡：用不落地、不動游標的 `previewRotation` 試算，跟「開始循環」分開。
    public func previewRotation(id: UUID) async {
        do {
            guard let blueprint = try await plannedProvider?.previewRotation(id: id) else { return }
            pendingStart = PendingStart(source: .rotation(id), blueprint: blueprint)
        } catch {
            errorMessage = .training("training.error.loadStatus \(error.localizedDescription)")
        }
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
