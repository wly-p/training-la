import Foundation
import SharedKernel

/// 開始新場次：workout 一建立就落地，之後每記一組都整包重存（中途被殺掉不掉資料）。
public struct StartWorkout: Sendable {
    private let repository: any WorkoutRepository
    private let makeID: @Sendable () -> UUID
    private let now: @Sendable () -> Date
    private let today: @Sendable () -> DayDate

    public init(
        repository: any WorkoutRepository,
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        now: @escaping @Sendable () -> Date = { Date() },
        today: @escaping @Sendable () -> DayDate = { DayDate(Date()) }
    ) {
        self.repository = repository
        self.makeID = makeID
        self.now = now
        self.today = today
    }

    public func callAsFunction() async throws -> Workout {
        let workout = Workout(id: makeID(), day: today(), startedAt: now())
        try await repository.save(workout)
        return workout
    }
}

/// 找回進行中的場次（App 重啟後恢復）。
public struct ResumeWorkout: Sendable {
    private let repository: any WorkoutRepository

    public init(repository: any WorkoutRepository) {
        self.repository = repository
    }

    public func callAsFunction() async throws -> Workout? {
        try await repository.activeWorkout()
    }
}

/// 進行中的每一步落地（記一組、改備註都走這裡）。
public struct SaveWorkoutProgress: Sendable {
    private let repository: any WorkoutRepository

    public init(repository: any WorkoutRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ workout: Workout) async throws {
        try await repository.save(workout)
    }
}

public enum FinishWorkoutError: Error, Equatable, Sendable {
    case feelingOutOfRange
}

/// 結束場次：補上 endedAt / 感受 / 備註。
public struct FinishWorkout: Sendable {
    private let repository: any WorkoutRepository
    private let now: @Sendable () -> Date

    public init(
        repository: any WorkoutRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.now = now
    }

    @discardableResult
    public func callAsFunction(_ workout: Workout, overallFeeling: Int?, note: String?) async throws -> Workout {
        if let feeling = overallFeeling, !(1...5).contains(feeling) {
            throw FinishWorkoutError.feelingOutOfRange
        }
        var finished = workout
        finished.endedAt = now()
        finished.overallFeeling = overallFeeling
        finished.note = note?.isEmpty == true ? nil : note
        try await repository.save(finished)
        return finished
    }
}

/// 放棄場次（沒記任何一組就退出時清掉空 workout）。
public struct DiscardWorkout: Sendable {
    private let repository: any WorkoutRepository

    public init(repository: any WorkoutRepository) {
        self.repository = repository
    }

    public func callAsFunction(id: UUID) async throws {
        try await repository.delete(id: id)
    }
}

/// 「上次」提示：某動作最近一次完成場次的各組。
public struct LastPerformance: Sendable {
    private let repository: any WorkoutRepository

    public init(repository: any WorkoutRepository) {
        self.repository = repository
    }

    public func callAsFunction(exerciseId: UUID, excludingWorkout: UUID?) async throws -> [WorkoutSet] {
        try await repository.lastPerformance(exerciseId: exerciseId, excludingWorkout: excludingWorkout)
    }
}
