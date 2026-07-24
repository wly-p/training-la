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
    /// 可套用的課表範本（「選範本開始」的來源）。
    public private(set) var templates: [PlannedTemplateSummary] = []
    /// 啟用中的循環課表（每組今天輪到哪張）；可多組並行。
    public private(set) var rotations: [PlannedRotationSummary] = []
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
            templates = try await plannedProvider?.templates() ?? []
            rotations = try await plannedProvider?.activeRotations() ?? []
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
