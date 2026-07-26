import Foundation
import SharedKernel

// MARK: - 課表 CRUD

public struct ListPrograms: Sendable {
    private let repository: any ProgramRepository
    public init(repository: any ProgramRepository) { self.repository = repository }
    public func callAsFunction() async throws -> [Program] { try await repository.all() }
}

public struct GetProgram: Sendable {
    private let repository: any ProgramRepository
    public init(repository: any ProgramRepository) { self.repository = repository }
    public func callAsFunction(id: UUID) async throws -> Program? { try await repository.get(id: id) }
}

/// 建立一份新的長期課表（預設 1 週空 grid），附到清單末端。
public struct CreateProgram: Sendable {
    private let repository: any ProgramRepository
    private let makeID: @Sendable () -> UUID
    private let now: @Sendable () -> Date

    public init(
        repository: any ProgramRepository,
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.makeID = makeID
        self.now = now
    }

    @discardableResult
    public func callAsFunction(name: String, cycleLength: Int = 7) async throws -> Program {
        let validName = try validatedProgramName(name)
        let orderIndex = (try await repository.all().map(\.orderIndex).max() ?? -1) + 1
        let timestamp = now()
        let program = Program(
            id: makeID(),
            name: validName,
            orderIndex: orderIndex,
            cycleLength: max(1, cycleLength),
            days: [:],
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try await repository.save(program)
        return program
    }
}

/// 整包更新一份課表的名稱與週格內容（保留 id / source / orderIndex / createdAt）。
public struct UpdateProgram: Sendable {
    private let repository: any ProgramRepository
    private let now: @Sendable () -> Date

    public init(
        repository: any ProgramRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.now = now
    }

    public func callAsFunction(id: UUID, name: String, cycleLength: Int, days: [Int: WorkoutSpec]) async throws {
        guard var program = try await repository.get(id: id) else {
            throw ProgramRepositoryError.notFound(id: id)
        }
        let length = max(1, cycleLength)
        program.name = try validatedProgramName(name)
        program.cycleLength = length
        // 縮短週期時，丟掉落在範圍外的日子。
        program.days = days.filter { (0..<length).contains($0.key) }
        program.updatedAt = now()
        try await repository.save(program)
    }
}

/// 刪除一份課表，連同引用它的所有套用（過去已落地的真實排課不受影響）。
public struct DeleteProgram: Sendable {
    private let programRepository: any ProgramRepository
    private let assignmentRepository: any ProgramAssignmentRepository

    public init(
        programRepository: any ProgramRepository,
        assignmentRepository: any ProgramAssignmentRepository
    ) {
        self.programRepository = programRepository
        self.assignmentRepository = assignmentRepository
    }

    public func callAsFunction(id: UUID) async throws {
        for assignment in try await assignmentRepository.forProgram(id) {
            try await assignmentRepository.delete(id: assignment.id)
        }
        try await programRepository.delete(id: id)
    }
}

// MARK: - 套用（assignment）

public struct ListProgramAssignments: Sendable {
    private let repository: any ProgramAssignmentRepository
    public init(repository: any ProgramAssignmentRepository) { self.repository = repository }
    public func callAsFunction() async throws -> [ProgramAssignment] { try await repository.all() }
}

/// 套用一份課表：綁起始日 + 模式，建立一筆 assignment。
public struct ApplyProgram: Sendable {
    private let repository: any ProgramAssignmentRepository
    private let makeID: @Sendable () -> UUID

    public init(
        repository: any ProgramAssignmentRepository,
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.makeID = makeID
    }

    @discardableResult
    public func callAsFunction(programId: UUID, startDate: DayDate, mode: ProgramRunMode) async throws -> ProgramAssignment {
        let assignment = ProgramAssignment(id: makeID(), programId: programId, startDate: startDate, mode: mode)
        try await repository.save(assignment)
        return assignment
    }
}

/// 停用一份套用＝刪除 assignment（過去真實紀錄不動，未來投影停止）。
public struct DeleteProgramAssignment: Sendable {
    private let repository: any ProgramAssignmentRepository
    public init(repository: any ProgramAssignmentRepository) { self.repository = repository }
    public func callAsFunction(id: UUID) async throws { try await repository.delete(id: id) }
}

/// 一份長期課表「此刻」的進度（動作庫長期分頁進行中卡／詳情頁用）。
/// day＝從起始日算起的第幾天（1-based，對週期取模）；totalDays＝週期天數（目前模型的最佳可用長度）；
/// todayWorkoutName＝今天排的 workout 名（nil＝休息日）。
public struct ProgramProgress: Equatable, Sendable {
    public let assignmentId: UUID
    public let day: Int
    public let totalDays: Int
    public let todayWorkoutName: String?
    public init(assignmentId: UUID, day: Int, totalDays: Int, todayWorkoutName: String?) {
        self.assignmentId = assignmentId
        self.day = day
        self.totalDays = totalDays
        self.todayWorkoutName = todayWorkoutName
    }
}

/// 查某份長期課表此刻的進度（取它第一筆 assignment）。無 assignment＝nil（＝未啟用）。
public struct GetProgramProgress: Sendable {
    private let programRepository: any ProgramRepository
    private let assignmentRepository: any ProgramAssignmentRepository

    public init(
        programRepository: any ProgramRepository,
        assignmentRepository: any ProgramAssignmentRepository
    ) {
        self.programRepository = programRepository
        self.assignmentRepository = assignmentRepository
    }

    public func callAsFunction(programId: UUID, today: DayDate) async throws -> ProgramProgress? {
        guard let program = try await programRepository.get(id: programId),
              let assignment = try await assignmentRepository.all().first(where: { $0.programId == programId })
        else { return nil }
        let cycleDay = assignment.cycleDay(for: today, cycleLength: program.cycleLength)
        // cycleDay nil（起始日之前／once 已結束）→ day 夾在範圍內顯示。
        let dayIndex = cycleDay ?? 0
        return ProgramProgress(
            assignmentId: assignment.id,
            day: dayIndex + 1,
            totalDays: program.cycleLength,
            todayWorkoutName: program.workout(dayIndex: dayIndex)?.name
        )
    }
}

/// 重設長期課表進度（詳情頁「重設進度 → 回到 D1」）：把 assignment 起始日移到今天、清補登游標。
public struct ResetProgramProgress: Sendable {
    private let repository: any ProgramAssignmentRepository
    public init(repository: any ProgramAssignmentRepository) { self.repository = repository }

    public func callAsFunction(programId: UUID, today: DayDate) async throws {
        guard var assignment = try await repository.all().first(where: { $0.programId == programId }) else { return }
        assignment.startDate = today
        assignment.lastReconciledDate = nil
        try await repository.save(assignment)
    }
}

// MARK: - 投影（未來，不入 DB）

/// 一則未來投影：某天、某套用、排定的 workout。
public struct ProjectedWorkout: Identifiable, Equatable, Sendable {
    public let date: DayDate
    public let assignmentId: UUID
    public let programId: UUID
    public let programName: String
    public let spec: WorkoutSpec

    public init(date: DayDate, assignmentId: UUID, programId: UUID, programName: String, spec: WorkoutSpec) {
        self.date = date
        self.assignmentId = assignmentId
        self.programId = programId
        self.programName = programName
        self.spec = spec
    }

    public var id: String { "\(assignmentId.uuidString)-\(date.isoString)" }
}

/// 算出某日期範圍內、今天（含）以後的投影建議。過去交給補登（真實紀錄），故不投影。
/// 已落地成真實排課（同 assignment 同一天）者略過，避免重複顯示。
public struct ProjectSchedule: Sendable {
    private let programRepository: any ProgramRepository
    private let assignmentRepository: any ProgramAssignmentRepository
    private let planRepository: any PlanWorkoutRepository

    public init(
        programRepository: any ProgramRepository,
        assignmentRepository: any ProgramAssignmentRepository,
        planRepository: any PlanWorkoutRepository
    ) {
        self.programRepository = programRepository
        self.assignmentRepository = assignmentRepository
        self.planRepository = planRepository
    }

    public func callAsFunction(from: DayDate, to: DayDate, today: DayDate) async throws -> [ProjectedWorkout] {
        guard from <= to else { return [] }
        let assignments = try await assignmentRepository.all()
        guard !assignments.isEmpty else { return [] }
        let programsById = Dictionary(
            (try await programRepository.all()).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let materialized = Set(
            (try await planRepository.all()).compactMap { plan in
                plan.assignmentId.map { AssignmentDay(assignmentId: $0, date: plan.date) }
            }
        )
        let rangeStart = max(from, today)   // 今天含以後才投影
        var result: [ProjectedWorkout] = []
        for assignment in assignments {
            guard let program = programsById[assignment.programId] else { continue }
            var day = rangeStart
            while day <= to {
                if let cycleDay = assignment.cycleDay(for: day, cycleLength: program.cycleLength),
                   let spec = program.workout(dayIndex: cycleDay),
                   !materialized.contains(AssignmentDay(assignmentId: assignment.id, date: day)) {
                    result.append(ProjectedWorkout(
                        date: day, assignmentId: assignment.id, programId: program.id,
                        programName: program.name, spec: spec
                    ))
                }
                day = day.adding(days: 1)
            }
        }
        return result.sorted { $0.date < $1.date }
    }
}

/// 把一則投影落地成當天的真實排課（未開始）。使用者從月曆某天「加入這天」時用。
/// 冪等：同 (assignment, date) 已有真實紀錄就不重複建。長期 spec 的重量表達式在這裡收斂。
public struct MaterializeProjectedWorkout: Sendable {
    private let planRepository: any PlanWorkoutRepository
    private let exerciseCatalog: any PlanExerciseCatalog
    private let lastPerformedWeightLookup: any LastPerformedWeightLookup
    private let makeID: @Sendable () -> UUID

    public init(
        planRepository: any PlanWorkoutRepository,
        exerciseCatalog: any PlanExerciseCatalog,
        lastPerformedWeightLookup: any LastPerformedWeightLookup,
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.planRepository = planRepository
        self.exerciseCatalog = exerciseCatalog
        self.lastPerformedWeightLookup = lastPerformedWeightLookup
        self.makeID = makeID
    }

    @discardableResult
    public func callAsFunction(_ projected: ProjectedWorkout) async throws -> PlanWorkout? {
        let onDate = try await planRepository.onDate(projected.date)
        if onDate.contains(where: { $0.assignmentId == projected.assignmentId }) { return nil }
        let orderIndex = (onDate.map(\.orderIndex).max() ?? -1) + 1
        let catalog = try await exerciseCatalog.exercises()
        let sets = try await resolvedPlanSets(
            from: projected.spec.sets, catalog: catalog, lookup: lastPerformedWeightLookup, makeID: makeID
        )
        let plan = PlanWorkout(
            id: makeID(),
            name: projected.spec.name.isEmpty ? nil : projected.spec.name,
            date: projected.date,
            status: .notStarted,
            templateId: nil,
            origin: .program,
            assignmentId: projected.assignmentId,
            orderIndex: orderIndex,
            sets: sets
        )
        try await planRepository.save(plan)
        return plan
    }
}

// MARK: - 補登（app 開啟：把過去漏做的投影落地成 未開始 真實紀錄）

/// 對每個 active 套用，掃 [起始日/上次補到隔天 … 昨天]，缺的 (assignment,date) 建 notStarted 快照。
/// 冪等：靠既有紀錄比對 + assignment.lastReconciledDate 限縮。回傳新建幾筆。
public struct ReconcileProgramAssignments: Sendable {
    private let programRepository: any ProgramRepository
    private let assignmentRepository: any ProgramAssignmentRepository
    private let planRepository: any PlanWorkoutRepository
    private let exerciseCatalog: any PlanExerciseCatalog
    private let lastPerformedWeightLookup: any LastPerformedWeightLookup
    private let makeID: @Sendable () -> UUID

    public init(
        programRepository: any ProgramRepository,
        assignmentRepository: any ProgramAssignmentRepository,
        planRepository: any PlanWorkoutRepository,
        exerciseCatalog: any PlanExerciseCatalog,
        lastPerformedWeightLookup: any LastPerformedWeightLookup,
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.programRepository = programRepository
        self.assignmentRepository = assignmentRepository
        self.planRepository = planRepository
        self.exerciseCatalog = exerciseCatalog
        self.lastPerformedWeightLookup = lastPerformedWeightLookup
        self.makeID = makeID
    }

    @discardableResult
    public func callAsFunction(today: DayDate) async throws -> Int {
        let assignments = try await assignmentRepository.all()
        guard !assignments.isEmpty else { return 0 }
        let programsById = Dictionary(
            (try await programRepository.all()).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let catalog = try await exerciseCatalog.exercises()
        let existing = try await planRepository.all()
        var materialized = Set(
            existing.compactMap { plan in
                plan.assignmentId.map { AssignmentDay(assignmentId: $0, date: plan.date) }
            }
        )
        var nextOrderIndex = Dictionary(grouping: existing, by: \.date)
            .mapValues { ($0.map(\.orderIndex).max() ?? -1) + 1 }

        let scanEnd = today.adding(days: -1)   // 只補到昨天；今天維持「建議」
        var created = 0
        for assignment in assignments {
            guard let program = programsById[assignment.programId] else { continue }
            let resumeFrom = assignment.lastReconciledDate.map { $0.adding(days: 1) } ?? assignment.startDate
            let scanStart = max(resumeFrom, assignment.startDate)
            guard scanStart <= scanEnd else { continue }

            var day = scanStart
            while day <= scanEnd {
                let key = AssignmentDay(assignmentId: assignment.id, date: day)
                if let cycleDay = assignment.cycleDay(for: day, cycleLength: program.cycleLength),
                   let spec = program.workout(dayIndex: cycleDay),
                   !materialized.contains(key) {
                    let order = nextOrderIndex[day, default: 0]
                    nextOrderIndex[day] = order + 1
                    let plan = try await makePlan(
                        from: spec, on: day, assignmentId: assignment.id, orderIndex: order, catalog: catalog
                    )
                    try await planRepository.save(plan)
                    materialized.insert(key)
                    created += 1
                }
                day = day.adding(days: 1)
            }
            var updated = assignment
            updated.lastReconciledDate = scanEnd
            try await assignmentRepository.save(updated)
        }
        return created
    }

    private func makePlan(
        from spec: WorkoutSpec, on date: DayDate, assignmentId: UUID, orderIndex: Int, catalog: [PlanCatalogExercise]
    ) async throws -> PlanWorkout {
        let sets = try await resolvedPlanSets(
            from: spec.sets, catalog: catalog, lookup: lastPerformedWeightLookup, makeID: makeID
        )
        return PlanWorkout(
            id: makeID(),
            name: spec.name.isEmpty ? nil : spec.name,
            date: date,
            status: .notStarted,
            templateId: nil,
            origin: .program,
            assignmentId: assignmentId,
            orderIndex: orderIndex,
            sets: sets
        )
    }
}

/// (assignment, date) 複合鍵：判斷某套用某天是否已落地。
private struct AssignmentDay: Hashable {
    let assignmentId: UUID
    let date: DayDate
}

/// 長期課表名稱驗證：去頭尾空白、不可為空。
func validatedProgramName(_ name: String) throws -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw PlanWorkoutValidationError.emptyName }
    return trimmed
}
