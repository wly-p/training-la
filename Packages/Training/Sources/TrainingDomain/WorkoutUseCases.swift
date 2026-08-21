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

/// 已完成場次（新到舊）：訓練首頁「本週」統計＋「最近練過」＋「和上次比」用。
///
/// 帶上限而不是全撈：這支在每次進訓練分頁時都會跑，而它要的只是「這週 ＋ 最近幾場」。
/// 200 場的資料量下全撈實測 0.29s，且隨紀錄數線性成長——那是每次切到訓練分頁都要付的錢。
///
/// 上限的取捨：`lastComparison`（開練前預覽的「和上次比」）要找「最近一場做過這個主項的場次」，
/// 若那一場落在上限之外就找不到，卡片不顯示——這是刻意的降級，不會出錯只是少一張卡。
public struct RecentWorkouts: Sendable {
    private let repository: any WorkoutRepository
    private let limit: Int?

    /// - Parameter limit: 預設 60 場，約覆蓋週四練的四個月。傳 nil＝全部。
    public init(repository: any WorkoutRepository, limit: Int? = 60) {
        self.repository = repository
        self.limit = limit
    }

    public func callAsFunction() async throws -> [Workout] {
        try await repository.finishedWorkouts(limit: limit)
    }
}

/// 完成摘要（13a）的 PR 播報：這場某動作的代表組，跟這個動作先前所有場次比是否創新高。
///
/// 判定規則住在 `SharedKernel.PersonalRecordRule`——原本 Training 與 History 各留一份
/// 「薄的純函式版本」，結果兩份悄悄長歪了（體檢 P4-4），現在收斂成同一支。
public struct ExercisePRAnnouncement: Identifiable, Equatable, Sendable {
    /// 對應 `PersonalRecordRule.Kind`，只是保留這一層讓 Training 的呼叫端不必 import 規則型別。
    public enum Kind: Equatable, Sendable {
        case newRepsAtWeight
        case newWeightAtReps
        case firstEver

        init(_ kind: PersonalRecordRule.Kind) {
            switch kind {
            case .newRepsAtWeight: self = .newRepsAtWeight
            case .newWeight: self = .newWeightAtReps
            case .firstEver: self = .firstEver
            }
        }
    }
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

/// 掃這場每個動作的代表組，跟先前歷史比對出 PR。規則見 `PersonalRecordRule`。
public struct DetectPersonalRecords: Sendable {
    private let repository: any WorkoutRepository

    public init(repository: any WorkoutRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ workout: Workout) async throws -> [ExercisePRAnnouncement] {
        var result: [ExercisePRAnnouncement] = []
        for block in workout.blocks {
            let doneSets = block.sets.filter { $0.status == .done }
            guard let best = PersonalRecordRule.representative(
                of: doneSets.map { .init(weight: $0.weight, reps: $0.reps) }
            ) else { continue }
            let history = try await repository.exerciseHistory(exerciseId: block.exerciseId)
                .filter { $0.workoutId != workout.id && $0.set.status == .done }
                .map { PersonalRecordRule.Performance(weight: $0.set.weight, reps: $0.set.reps) }
            guard let kind = PersonalRecordRule.evaluate(best, against: history) else { continue }
            result.append(ExercisePRAnnouncement(
                exerciseId: block.exerciseId, weight: best.weight, reps: best.reps,
                kind: .init(kind)
            ))
        }
        return result
    }
}
