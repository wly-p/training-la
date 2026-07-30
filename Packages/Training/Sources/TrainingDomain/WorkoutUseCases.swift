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

    /// `blueprint` 非 nil＝照課表開始（workout 記下排課來源）。
    public func callAsFunction(blueprint: PlannedWorkoutBlueprint? = nil) async throws -> Workout {
        let workout = Workout(
            id: makeID(),
            day: today(),
            planWorkoutId: blueprint?.planWorkoutId,
            startedAt: now()
        )
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

/// 結束場次：補上 endedAt / 感受 / 備註；照課表的場次順帶把排課標成 done（App 端邏輯，見 DOMAIN.md §8）。
public struct FinishWorkout: Sendable {
    private let repository: any WorkoutRepository
    private let planProgress: (any PlanProgressRecorder)?
    private let now: @Sendable () -> Date

    public init(
        repository: any WorkoutRepository,
        planProgress: (any PlanProgressRecorder)? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.planProgress = planProgress
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
        if let planWorkoutId = finished.planWorkoutId {
            // 紀錄本身已保存成功；標記排課失敗不應讓整個結束流程失敗
            try? await planProgress?.markDone(planWorkoutId: planWorkoutId)
        }
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

/// 已完成場次（新到舊）：訓練首頁「本週」統計＋「重複上次」用。
public struct RecentWorkouts: Sendable {
    private let repository: any WorkoutRepository

    public init(repository: any WorkoutRepository) {
        self.repository = repository
    }

    public func callAsFunction() async throws -> [Workout] {
        try await repository.finishedWorkouts()
    }
}

/// 完成摘要（13a）的 PR 播報：這場某動作的代表組，跟這個動作先前所有場次比，
/// 在「這個重量的次數」或「這個次數的重量」任一維度創新高。跟 91-weight-model.md／
/// History 趨勢圖（Phase 4）同一套判定規則，因為兩個 package 不互相 import Presentation，
/// 各自保留一份薄的純函式版本，不強行共用。
public struct ExercisePRAnnouncement: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case newRepsAtWeight, newWeightAtReps }
    public let exerciseId: UUID
    public let weight: Weight
    public let reps: Int
    public let kind: Kind
    public var id: UUID { exerciseId }

    public init(exerciseId: UUID, weight: Weight, reps: Int, kind: Kind) {
        self.exerciseId = exerciseId
        self.weight = weight
        self.reps = reps
        self.kind = kind
    }
}

/// 掃這場每個動作的代表組（最高重量，同重量比次數），跟這個動作先前的歷史比對出 PR。
public struct DetectPersonalRecords: Sendable {
    private let repository: any WorkoutRepository

    public init(repository: any WorkoutRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ workout: Workout) async throws -> [ExercisePRAnnouncement] {
        var result: [ExercisePRAnnouncement] = []
        for block in workout.blocks {
            let doneSets = block.sets.filter { $0.status == .done }
            guard let best = doneSets.max(by: { ($0.weight.value, $0.reps) < ($1.weight.value, $1.reps) })
            else { continue }
            let history = try await repository.exerciseHistory(exerciseId: block.exerciseId)
                .filter { $0.workoutId != workout.id }
            // 只在「該重量／該次數以前真的出現過」時才算「創新高」——完全沒比較基準的維度
            // 不能拿 0 當預設基準，否則隨便一組都會被誤判成「創新高」。
            let bestRepsAtThisWeight = history
                .filter { $0.set.weight.value == best.weight.value }.map(\.set.reps).max()
            let bestWeightAtThisReps = history
                .filter { $0.set.reps == best.reps }.map(\.set.weight.value).max()
            if let bestReps = bestRepsAtThisWeight, best.reps > bestReps {
                result.append(ExercisePRAnnouncement(exerciseId: block.exerciseId, weight: best.weight, reps: best.reps, kind: .newRepsAtWeight))
            } else if let bestWeight = bestWeightAtThisReps, best.weight.value > bestWeight {
                result.append(ExercisePRAnnouncement(exerciseId: block.exerciseId, weight: best.weight, reps: best.reps, kind: .newWeightAtReps))
            } else if history.isEmpty {
                // 這個動作完全沒有歷史紀錄——第一次練，任何一組都算創新高。
                result.append(ExercisePRAnnouncement(exerciseId: block.exerciseId, weight: best.weight, reps: best.reps, kind: .newWeightAtReps))
            }
        }
        return result
    }
}
