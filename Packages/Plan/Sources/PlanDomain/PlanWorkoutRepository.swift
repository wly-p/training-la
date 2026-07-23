import Foundation
import SharedKernel

public protocol PlanWorkoutRepository: Sendable {
    /// 全部排課（有日期者日期近到遠、循環者依 orderIndex）。
    func all() async throws -> [PlanWorkout]
    func get(id: UUID) async throws -> PlanWorkout?
    /// 整包寫入/取代。
    func save(_ planWorkout: PlanWorkout) async throws
    func delete(id: UUID) async throws
    /// 指定日期的排課。
    func onDate(_ day: DayDate) async throws -> [PlanWorkout]
    /// 有沒有任何一組排課目標引用這個動作（給刪動作的 in_use 檢查）。
    func usesExercise(_ exerciseId: UUID) async throws -> Bool
}

public enum PlanWorkoutRepositoryError: Error, Equatable, Sendable {
    case notFound(id: UUID)
}
