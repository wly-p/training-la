import Foundation
import PlanDomain
import SharedKernel

actor MockPlanWorkoutRepository: PlanWorkoutRepository {
    private(set) var storage: [UUID: PlanWorkout] = [:]
    private(set) var saveCount = 0

    func seed(_ items: [PlanWorkout]) {
        for item in items { storage[item.id] = item }
    }

    func all() async throws -> [PlanWorkout] {
        storage.values.sorted { $0.orderIndex < $1.orderIndex }
    }

    func get(id: UUID) async throws -> PlanWorkout? { storage[id] }

    func save(_ planWorkout: PlanWorkout) async throws {
        saveCount += 1
        storage[planWorkout.id] = planWorkout
    }

    func delete(id: UUID) async throws {
        guard storage.removeValue(forKey: id) != nil else {
            throw PlanWorkoutRepositoryError.notFound(id: id)
        }
    }

    func onDate(_ day: DayDate) async throws -> [PlanWorkout] {
        storage.values.filter { $0.date == day }.sorted { $0.orderIndex < $1.orderIndex }
    }

    func usesExercise(_ exerciseId: UUID) async throws -> Bool {
        storage.values.contains { $0.sets.contains { $0.exerciseId == exerciseId } }
    }
}
