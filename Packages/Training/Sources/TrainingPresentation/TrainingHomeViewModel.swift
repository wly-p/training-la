import Foundation
import Observation
import TrainingDomain

@MainActor
@Observable
public final class TrainingHomeViewModel {
    /// 有進行中的場次可以繼續。
    public private(set) var resumable: Workout?
    /// 今天的排課（照課表訓練的來源）。
    public private(set) var todaysPlan: PlannedWorkoutBlueprint?
    /// 非 nil → 呈現記錄畫面。
    public var recording: Workout?
    /// 本地化錯誤字串（延後解析，由 View 依 Environment locale 顯示）。
    public private(set) var errorMessage: LocalizedStringResource?

    private let startWorkout: StartWorkout
    private let resumeWorkout: ResumeWorkout
    private let plannedProvider: (any PlannedWorkoutProvider)?

    public init(
        startWorkout: StartWorkout,
        resumeWorkout: ResumeWorkout,
        plannedProvider: (any PlannedWorkoutProvider)? = nil
    ) {
        self.startWorkout = startWorkout
        self.resumeWorkout = resumeWorkout
        self.plannedProvider = plannedProvider
    }

    public func refresh() async {
        do {
            resumable = try await resumeWorkout()
            todaysPlan = try await plannedProvider?.todaysPlan()
            errorMessage = nil
        } catch {
            errorMessage = .training("training.error.loadStatus \(error.localizedDescription)")
        }
    }

    /// 自由訓練（不帶課表）。
    public func startFree() async {
        await start(blueprint: nil)
    }

    /// 照今天的課表開始。
    public func startFromPlan() async {
        await start(blueprint: todaysPlan)
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
