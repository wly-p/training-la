import Foundation
import SharedKernel

public struct LoadRotation: Sendable {
    private let repository: any RotationRepository
    public init(repository: any RotationRepository) { self.repository = repository }
    public func callAsFunction() async throws -> Rotation { try await repository.load() }
}

/// 整包取代循環的 workouts（保留游標，超出範圍會被 clamp）。
public struct SaveRotationWorkouts: Sendable {
    private let repository: any RotationRepository
    public init(repository: any RotationRepository) { self.repository = repository }

    public func callAsFunction(_ workouts: [WorkoutSpec]) async throws {
        let existing = try await repository.load()
        try await repository.save(Rotation(workouts: workouts, cursor: existing.cursor))
    }
}

/// 開始環尋今天的 workout：把目前輪到的 workout 快照成當日 PlanWorkout、游標往下一張。
public struct StartRotation: Sendable {
    private let rotationRepository: any RotationRepository
    private let planRepository: any PlanWorkoutRepository
    private let makeID: @Sendable () -> UUID

    public init(
        rotationRepository: any RotationRepository,
        planRepository: any PlanWorkoutRepository,
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.rotationRepository = rotationRepository
        self.planRepository = planRepository
        self.makeID = makeID
    }

    /// 回傳建立的當日排課；空循環回 nil。
    @discardableResult
    public func callAsFunction(date: DayDate) async throws -> PlanWorkout? {
        let rotation = try await rotationRepository.load()
        guard let spec = rotation.current else { return nil }
        let orderIndex = (try await planRepository.onDate(date).map(\.orderIndex).max() ?? -1) + 1
        let sets = spec.sets.map { set in
            PlanSet(
                id: makeID(),
                exerciseId: set.exerciseId,
                exerciseIndex: set.exerciseIndex,
                setIndex: set.setIndex,
                targetWeight: set.targetWeight,
                targetReps: set.targetReps,
                restSec: set.restSec
            )
        }
        let plan = PlanWorkout(
            id: makeID(),
            name: spec.name.isEmpty ? nil : spec.name,
            date: date,
            status: .notStarted,
            templateId: nil,
            orderIndex: orderIndex,
            sets: sets
        )
        try await planRepository.save(plan)
        try await rotationRepository.save(rotation.advanced())
        return plan
    }
}
