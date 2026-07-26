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

/// 訓練首頁「重複上次」列：最近一場已完成場次的摘要。
public struct RecentSessionSummary: Equatable, Sendable {
    public let workoutId: UUID
    public let day: DayDate
    /// 範本/排課名；nil＝那場是自由訓練。
    public let name: String?
    public let setCount: Int
}

@MainActor
@Observable
public final class TrainingHomeViewModel {
    /// 有進行中的場次可以繼續。
    public private(set) var resumable: Workout?
    /// 今天的排課（照課表訓練的來源）。
    public private(set) var todaysPlan: PlannedWorkoutBlueprint?
    /// 可套用的課表範本（「選範本開始」的來源）。
    public private(set) var templates: [PlannedTemplateSummary] = []
    /// 啟用中的循環課表（每組今天輪到哪張）；可多組並行。
    public private(set) var rotations: [PlannedRotationSummary] = []
    /// 本週次數/時長/7 天完成狀態。
    public private(set) var weekSummary: WeekTrainingSummary?
    /// 最近一場已完成場次（「重複上次」列）；nil＝完全沒練過。
    public private(set) var lastSession: RecentSessionSummary?
    /// 非 nil → 呈現記錄畫面。
    public var recording: Workout?
    /// 本地化錯誤字串（延後解析，由 View 依 Environment locale 顯示）。
    public private(set) var errorMessage: LocalizedStringResource?

    /// 進行中的計畫數（今天指定 + 隨時可做），Header kicker 用。
    public var activePlanCount: Int {
        (todaysPlan != nil ? 1 : 0) + rotations.count
    }

    private let startWorkout: StartWorkout
    private let resumeWorkout: ResumeWorkout
    private let recentWorkouts: RecentWorkouts?
    private let plannedProvider: (any PlannedWorkoutProvider)?
    private let today: @Sendable () -> DayDate

    public init(
        startWorkout: StartWorkout,
        resumeWorkout: ResumeWorkout,
        recentWorkouts: RecentWorkouts? = nil,
        plannedProvider: (any PlannedWorkoutProvider)? = nil,
        today: @escaping @Sendable () -> DayDate = { DayDate(Date()) }
    ) {
        self.startWorkout = startWorkout
        self.resumeWorkout = resumeWorkout
        self.recentWorkouts = recentWorkouts
        self.plannedProvider = plannedProvider
        self.today = today
    }

    public func refresh() async {
        do {
            resumable = try await resumeWorkout()
            todaysPlan = try await plannedProvider?.todaysPlan()
            templates = try await plannedProvider?.templates() ?? []
            rotations = try await plannedProvider?.activeRotations() ?? []
            try await refreshRecentWorkouts()
            errorMessage = nil
        } catch {
            errorMessage = .training("training.error.loadStatus \(error.localizedDescription)")
        }
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

    public func dismissError() { errorMessage = nil }

    private func start(blueprint: PlannedWorkoutBlueprint?) async {
        do {
            recording = try await startWorkout(blueprint: blueprint)
        } catch {
            errorMessage = .training("training.error.startFailed \(error.localizedDescription)")
        }
    }
}
