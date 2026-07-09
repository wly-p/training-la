import Foundation
import Observation
import TrainingDomain

@MainActor
@Observable
public final class TrainingHomeViewModel {
    /// 有進行中的場次可以繼續。
    public private(set) var resumable: Workout?
    /// 非 nil → 呈現記錄畫面。
    public var recording: Workout?
    public private(set) var errorMessage: String?

    private let startWorkout: StartWorkout
    private let resumeWorkout: ResumeWorkout

    public init(startWorkout: StartWorkout, resumeWorkout: ResumeWorkout) {
        self.startWorkout = startWorkout
        self.resumeWorkout = resumeWorkout
    }

    public func refresh() async {
        do {
            resumable = try await resumeWorkout()
            errorMessage = nil
        } catch {
            errorMessage = "讀取進行中訓練失敗：\(error.localizedDescription)"
        }
    }

    public func startNew() async {
        do {
            recording = try await startWorkout()
        } catch {
            errorMessage = "無法開始訓練：\(error.localizedDescription)"
        }
    }

    public func resume() {
        recording = resumable
    }

    public func dismissError() {
        errorMessage = nil
    }
}
