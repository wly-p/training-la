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
    /// 循環排課（date == nil），依 orderIndex 升序。
    func cycle() async throws -> [PlanWorkout]
}

public enum PlanWorkoutRepositoryError: Error, Equatable, Sendable {
    case notFound(id: UUID)
}
