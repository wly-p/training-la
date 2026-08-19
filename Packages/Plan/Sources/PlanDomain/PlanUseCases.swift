import Foundation
import SharedKernel

public struct ListPlanWorkouts: Sendable {
    private let repository: any PlanWorkoutRepository
    public init(repository: any PlanWorkoutRepository) { self.repository = repository }
    public func callAsFunction() async throws -> [PlanWorkout] { try await repository.all() }
}

public enum PlanWorkoutValidationError: Error, Equatable, Sendable {
    case empty      // 沒有任何動作
    case emptyName  // 範本沒有名稱
}

private func validatedTemplateName(_ raw: String) throws -> String {
    let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw PlanWorkoutValidationError.emptyName }
    return name
}

// MARK: - 當日排課（PlanWorkout）

/// 建立當日排課：指派 orderIndex（接在同一天現有排課之後）。
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
        date: DayDate,
        drafts: [ExerciseTargetDraft]
    ) async throws -> PlanWorkout {
        guard !drafts.isEmpty else { throw PlanWorkoutValidationError.empty }
        let orderIndex = (try await repository.onDate(date).map(\.orderIndex).max() ?? -1) + 1
        let planWorkout = PlanWorkout(
            id: makeID(),
            name: name?.isEmpty == true ? nil : name,
            date: date,
            status: .notStarted,
            templateId: nil,
            orderIndex: orderIndex,
            sets: PlanSet.make(from: drafts, makeID: makeID)
        )
        try await repository.save(planWorkout)
        return planWorkout
    }
}

/// 整包取代排課的 name/date/sets（不動 orderIndex / status / templateId）。
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
        date: DayDate,
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
            templateId: existing.templateId,
            // 沿用原本的來源標記，不要在編輯時被重設成 .manual。
            // 註：`assignmentId` 與 `weightSource` 目前仍會在這裡遺失（體檢 P4-1），
            // 那兩個跟長期課表的投影去重綁在一起，隨模型重做一起處理。
            origin: existing.origin,
            orderIndex: existing.orderIndex,
            sets: PlanSet.make(from: drafts, makeID: makeID)
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

/// 還原排課為未開始（刪除對應訓練場次、該排課已無完成紀錄時觸發）。
public struct RevertPlanWorkoutDone: Sendable {
    private let repository: any PlanWorkoutRepository
    public init(repository: any PlanWorkoutRepository) { self.repository = repository }

    public func callAsFunction(id: UUID) async throws {
        guard var planWorkout = try await repository.get(id: id) else { return }
        planWorkout.status = .notStarted
        try await repository.save(planWorkout)
    }
}

/// 決定「今天要做的排課」：今天指定日、還沒完成的第一張（依 orderIndex）。
/// 循環／排程規律留待 Phase 2 由排程層驅動。
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
        try await repository.onDate(today())
            .sorted { $0.orderIndex < $1.orderIndex }
            .first { $0.status != .done }
    }
}

// MARK: - 課表範本（WorkoutTemplate）

public struct ListTemplates: Sendable {
    private let repository: any WorkoutTemplateRepository
    public init(repository: any WorkoutTemplateRepository) { self.repository = repository }
    public func callAsFunction() async throws -> [WorkoutTemplate] { try await repository.all() }
}

public struct CreateTemplate: Sendable {
    private let repository: any WorkoutTemplateRepository
    private let makeID: @Sendable () -> UUID
    private let now: @Sendable () -> Date

    public init(
        repository: any WorkoutTemplateRepository,
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.makeID = makeID
        self.now = now
    }

    /// `sets` 逐組各自的重量表達式（絕對值／相對上次）由呼叫端（新版範本編輯器）決定，
    /// 這裡不再經過 `ExerciseTargetDraft`（那是「整個動作一個目標」的簡化輸入，逐組編輯用不上）。
    @discardableResult
    public func callAsFunction(name: String, sets: [PlanSet]) async throws -> WorkoutTemplate {
        guard !sets.isEmpty else { throw PlanWorkoutValidationError.empty }
        let validName = try validatedTemplateName(name)
        let orderIndex = (try await repository.all().map(\.orderIndex).max() ?? -1) + 1
        let timestamp = now()
        let template = WorkoutTemplate(
            id: makeID(),
            name: validName,
            source: .user,
            orderIndex: orderIndex,
            sets: sets,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try await repository.save(template)
        return template
    }
}

/// 整包取代範本的 name/sets（不動 source / orderIndex / createdAt）。
public struct UpdateTemplate: Sendable {
    private let repository: any WorkoutTemplateRepository
    private let makeID: @Sendable () -> UUID
    private let now: @Sendable () -> Date

    public init(
        repository: any WorkoutTemplateRepository,
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.makeID = makeID
        self.now = now
    }

    @discardableResult
    public func callAsFunction(id: UUID, name: String, sets: [PlanSet]) async throws -> WorkoutTemplate {
        guard !sets.isEmpty else { throw PlanWorkoutValidationError.empty }
        let validName = try validatedTemplateName(name)
        guard var existing = try await repository.get(id: id) else {
            throw WorkoutTemplateRepositoryError.notFound(id: id)
        }
        existing.name = validName
        existing.sets = sets
        existing.updatedAt = now()
        try await repository.save(existing)
        return existing
    }
}

/// 複製範本（14a）：深拷貝全部 sets（含逐組表達式），重新產生所有 id，
/// 名稱接上呼叫端給的後綴，排在清單末端。複製出來的是完全獨立的一份，改它不影響原本那份。
///
/// 後綴由呼叫端傳入而不是寫在這裡：Domain 拿不到 locale，寫死「· 副本」的話
/// 英文介面複製出來也會是中文（體檢 E2）。名稱會被持久化，所以要在寫入當下就解析成
/// 使用者當時的語言，不能像 UI 文案那樣延後解析。
public struct DuplicateTemplate: Sendable {
    private let repository: any WorkoutTemplateRepository
    private let makeID: @Sendable () -> UUID
    private let now: @Sendable () -> Date

    public init(
        repository: any WorkoutTemplateRepository,
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.makeID = makeID
        self.now = now
    }

    @discardableResult
    /// - Parameter nameSuffix: 接在原名後面的後綴（含分隔符），例如 `" · 副本"` / `" · Copy"`。
    public func callAsFunction(id: UUID, nameSuffix: String) async throws -> WorkoutTemplate {
        guard let original = try await repository.get(id: id) else {
            throw WorkoutTemplateRepositoryError.notFound(id: id)
        }
        let orderIndex = (try await repository.all().map(\.orderIndex).max() ?? -1) + 1
        let timestamp = now()
        let copy = WorkoutTemplate(
            id: makeID(),
            name: original.name + nameSuffix,
            source: .user,
            orderIndex: orderIndex,
            sets: original.sets.map { set in
                PlanSet(
                    id: makeID(),
                    exerciseId: set.exerciseId,
                    exerciseIndex: set.exerciseIndex,
                    setIndex: set.setIndex,
                    targetWeight: set.targetWeight,
                    targetReps: set.targetReps,
                    restSec: set.restSec
                )
            },
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try await repository.save(copy)
        return copy
    }
}

public struct DeleteTemplate: Sendable {
    private let repository: any WorkoutTemplateRepository
    public init(repository: any WorkoutTemplateRepository) { self.repository = repository }
    public func callAsFunction(id: UUID) async throws { try await repository.delete(id: id) }
}

/// 依範本實例化成當日排課：copy sets 快照（新 set id），status = notStarted，記下 templateId。
/// 範本的重量表達式在這裡收斂成確定公斤（見 `resolvedPlanSets`）。
public struct InstantiateTemplate: Sendable {
    private let templateRepository: any WorkoutTemplateRepository
    private let planRepository: any PlanWorkoutRepository
    private let preferences: any TrainingPreferenceStoring
    private let lastPerformedWeightLookup: any LastPerformedWeightLookup
    private let abilityValueLookup: any AbilityValueLookup
    private let makeID: @Sendable () -> UUID

    public init(
        templateRepository: any WorkoutTemplateRepository,
        planRepository: any PlanWorkoutRepository,
        preferences: any TrainingPreferenceStoring,
        lastPerformedWeightLookup: any LastPerformedWeightLookup,
        abilityValueLookup: any AbilityValueLookup,
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.templateRepository = templateRepository
        self.planRepository = planRepository
        self.preferences = preferences
        self.lastPerformedWeightLookup = lastPerformedWeightLookup
        self.abilityValueLookup = abilityValueLookup
        self.makeID = makeID
    }

    @discardableResult
    public func callAsFunction(templateId: UUID, date: DayDate) async throws -> PlanWorkout {
        guard let template = try await templateRepository.get(id: templateId) else {
            throw WorkoutTemplateRepositoryError.notFound(id: templateId)
        }
        let orderIndex = (try await planRepository.onDate(date).map(\.orderIndex).max() ?? -1) + 1
        let weightStep = preferences.loadWeightStep()
        // 範本永遠是 100% 的原始處方，沒有強度倍率概念（見 91-weight-model.md §9）。
        let sets = try await resolvedPlanSets(
            from: template.sets, weightStep: weightStep, intensityFactor: 1.0,
            lastPerformedLookup: lastPerformedWeightLookup, abilityValueLookup: abilityValueLookup, makeID: makeID
        )
        let plan = PlanWorkout(
            id: makeID(),
            name: template.name,
            date: date,
            status: .notStarted,
            templateId: template.id,
            origin: .template,
            orderIndex: orderIndex,
            sets: sets
        )
        try await planRepository.save(plan)
        return plan
    }
}
