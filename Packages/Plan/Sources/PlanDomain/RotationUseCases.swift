import Foundation
import SharedKernel

/// 全部循環課表（依 orderIndex）。
public struct ListRotations: Sendable {
    private let repository: any RotationRepository
    public init(repository: any RotationRepository) { self.repository = repository }
    public func callAsFunction() async throws -> [Rotation] { try await repository.all() }
}

/// 依 id 取一組循環。
public struct GetRotation: Sendable {
    private let repository: any RotationRepository
    public init(repository: any RotationRepository) { self.repository = repository }
    public func callAsFunction(id: UUID) async throws -> Rotation? { try await repository.get(id: id) }
}

/// 建立一組新的（空）循環課表，預設啟用，附到清單末端。
public struct CreateRotation: Sendable {
    private let repository: any RotationRepository
    private let makeID: @Sendable () -> UUID

    public init(
        repository: any RotationRepository,
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.makeID = makeID
    }

    @discardableResult
    public func callAsFunction(name: String) async throws -> Rotation {
        let validName = try validatedRotationName(name)
        let orderIndex = (try await repository.all().map(\.orderIndex).max() ?? -1) + 1
        let rotation = Rotation(id: makeID(), name: validName, orderIndex: orderIndex)
        try await repository.save(rotation)
        return rotation
    }
}

/// 重新命名一組循環（其餘不變）。
public struct RenameRotation: Sendable {
    private let repository: any RotationRepository
    public init(repository: any RotationRepository) { self.repository = repository }

    public func callAsFunction(id: UUID, name: String) async throws {
        guard var rotation = try await repository.get(id: id) else {
            throw RotationRepositoryError.notFound(id: id)
        }
        rotation.name = try validatedRotationName(name)
        try await repository.save(rotation)
    }
}

/// 整包取代某組循環的 workouts（保留游標，超出範圍會被 clamp）。
public struct SaveRotationWorkouts: Sendable {
    private let repository: any RotationRepository
    public init(repository: any RotationRepository) { self.repository = repository }

    public func callAsFunction(id: UUID, workouts: [WorkoutSpec]) async throws {
        guard var rotation = try await repository.get(id: id) else {
            throw RotationRepositoryError.notFound(id: id)
        }
        rotation.workouts = workouts
        rotation.cursor = min(rotation.cursor, max(0, workouts.count - 1))
        try await repository.save(rotation)
    }
}

/// 啟用／停用某組循環；**停用時游標歸零**（下次啟用從第一張重來）。
public struct SetRotationActive: Sendable {
    private let repository: any RotationRepository
    public init(repository: any RotationRepository) { self.repository = repository }

    public func callAsFunction(id: UUID, isActive: Bool) async throws {
        guard var rotation = try await repository.get(id: id) else {
            throw RotationRepositoryError.notFound(id: id)
        }
        rotation.isActive = isActive
        if !isActive { rotation.cursor = 0 }
        try await repository.save(rotation)
    }
}

public struct DeleteRotation: Sendable {
    private let repository: any RotationRepository
    public init(repository: any RotationRepository) { self.repository = repository }
    public func callAsFunction(id: UUID) async throws { try await repository.delete(id: id) }
}

/// 開始某組循環今天的 workout：把目前輪到的 workout 快照成當日 PlanWorkout、游標往下一張。
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

    /// 回傳建立的當日排課；找不到循環或空循環回 nil。
    @discardableResult
    public func callAsFunction(id: UUID, date: DayDate) async throws -> PlanWorkout? {
        guard let rotation = try await rotationRepository.get(id: id),
              let spec = rotation.current else { return nil }
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

/// 循環課表名稱驗證：去頭尾空白、不可為空。
func validatedRotationName(_ name: String) throws -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw PlanWorkoutValidationError.emptyName }
    return trimmed
}
