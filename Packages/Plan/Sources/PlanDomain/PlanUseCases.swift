import Foundation
import SharedKernel

public struct ListPlanWorkouts: Sendable {
    private let repository: any PlanWorkoutRepository
    public init(repository: any PlanWorkoutRepository) { self.repository = repository }
    public func callAsFunction() async throws -> [PlanWorkout] { try await repository.all() }
}

public enum PlanWorkoutValidationError: Error, Equatable, Sendable {
    case empty // 沒有任何動作
}

/// 建立排課：指派 orderIndex（接在現有循環課之後）。
public struct CreatePlanWorkout: Sendable {
    private let repository: any PlanWorkoutRepository
    private let makeID: @Sendable () -> UUID

    public init(
        repository: any PlanWorkoutRepository,
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.makeID = makeID
    }

    @discardableResult
    public func callAsFunction(
        name: String?,
        date: DayDate?,
        drafts: [ExerciseTargetDraft]
    ) async throws -> PlanWorkout {
        guard !drafts.isEmpty else { throw PlanWorkoutValidationError.empty }
        let orderIndex = (try await repository.all().map(\.orderIndex).max() ?? -1) + 1
        let planWorkout = PlanWorkout(
            id: makeID(),
            name: name?.isEmpty == true ? nil : name,
            date: date,
            status: .notStarted,
            orderIndex: orderIndex,
            sets: PlanWorkout.makeSets(from: drafts, makeID: makeID)
        )
        try await repository.save(planWorkout)
        return planWorkout
    }
}

/// 整包取代排課的 name/date/sets（不動 orderIndex）。
public struct UpdatePlanWorkout: Sendable {
    private let repository: any PlanWorkoutRepository
    private let makeID: @Sendable () -> UUID

    public init(
        repository: any PlanWorkoutRepository,
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.makeID = makeID
    }

    @discardableResult
    public func callAsFunction(
        id: UUID,
        name: String?,
        date: DayDate?,
        drafts: [ExerciseTargetDraft]
    ) async throws -> PlanWorkout {
        guard !drafts.isEmpty else { throw PlanWorkoutValidationError.empty }
        guard let existing = try await repository.get(id: id) else {
            throw PlanWorkoutRepositoryError.notFound(id: id)
        }
        let updated = PlanWorkout(
            id: existing.id,
            name: name?.isEmpty == true ? nil : name,
            date: date,
            status: existing.status,
            orderIndex: existing.orderIndex,
            sets: PlanWorkout.makeSets(from: drafts, makeID: makeID)
        )
        try await repository.save(updated)
        return updated
    }
}

public struct DeletePlanWorkout: Sendable {
    private let repository: any PlanWorkoutRepository
    public init(repository: any PlanWorkoutRepository) { self.repository = repository }
    public func callAsFunction(id: UUID) async throws { try await repository.delete(id: id) }
}

/// 標記排課完成（訓練結束時由 Training 透過 port 觸發）。
public struct MarkPlanWorkoutDone: Sendable {
    private let repository: any PlanWorkoutRepository
    public init(repository: any PlanWorkoutRepository) { self.repository = repository }

    public func callAsFunction(id: UUID) async throws {
        guard var planWorkout = try await repository.get(id: id) else { return }
        planWorkout.status = .done
        try await repository.save(planWorkout)
    }
}

/// 決定「今天要做的排課」——App 端邏輯（DOMAIN.md §8）。
/// 優先今天指定日的未完成排課；否則循環模式取 orderIndex 最小的 not_started，
/// 全部 done 時把整輪重設回 not_started 再取第一個。
public struct TodaysWorkout: Sendable {
    private let repository: any PlanWorkoutRepository
    private let today: @Sendable () -> DayDate

    public init(
        repository: any PlanWorkoutRepository,
        today: @escaping @Sendable () -> DayDate = { DayDate(Date()) }
    ) {
        self.repository = repository
        self.today = today
    }

    public func callAsFunction() async throws -> PlanWorkout? {
        // 1. 今天指定日、還沒完成的
        let dated = try await repository.onDate(today())
        if let next = dated.first(where: { $0.status != .done }) {
            return next
        }
        // 今天有指定日排課但都完成了＝今天沒有待辦（不繞回循環）
        if !dated.isEmpty {
            return nil
        }
        // 2. 循環模式
        let cycle = try await repository.cycle().sorted { $0.orderIndex < $1.orderIndex }
        guard !cycle.isEmpty else { return nil }
        if let next = cycle.first(where: { $0.status == .notStarted }) {
            return next
        }
        // 全部做完 → 重設整輪，回到第一個
        for var workout in cycle where workout.status != .notStarted {
            workout.status = .notStarted
            try await repository.save(workout)
        }
        return cycle.first.map {
            var w = $0
            w.status = .notStarted
            return w
        }
    }
}
