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
    public func callAsFunction(
        name: String,
        cycleLength: Int = 7,
        days: [Int: WorkoutSpec] = [:],
        intensityFactor: Double = 1.0
    ) async throws -> Program {
        let validName = try validatedProgramName(name)
        let orderIndex = (try await repository.all().map(\.orderIndex).max() ?? -1) + 1
        let timestamp = now()
        let length = max(1, cycleLength)
        let program = Program(
            id: makeID(),
            name: validName,
            orderIndex: orderIndex,
            cycleLength: length,
            days: days.filter { (0..<length).contains($0.key) },
            intensityFactor: intensityFactor,
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

    public func callAsFunction(
        id: UUID, name: String, cycleLength: Int, days: [Int: WorkoutSpec], intensityFactor: Double? = nil
    ) async throws {
        guard var program = try await repository.get(id: id) else {
            throw ProgramRepositoryError.notFound(id: id)
        }
        let length = max(1, cycleLength)
        program.name = try validatedProgramName(name)
        program.cycleLength = length
        // 縮短週期時，丟掉落在範圍外的日子。
        program.days = days.filter { (0..<length).contains($0.key) }
        if let intensityFactor { program.intensityFactor = intensityFactor }
        program.updatedAt = now()
        try await repository.save(program)
    }
}

/// 設定長期課表的強度倍率（14b：計畫層一個數字，格子的覆寫值不受影響）。
public struct SetProgramIntensityFactor: Sendable {
    private let repository: any ProgramRepository
    private let now: @Sendable () -> Date

    public init(
        repository: any ProgramRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.now = now
    }

    public func callAsFunction(id: UUID, intensityFactor: Double) async throws {
        guard var program = try await repository.get(id: id) else {
            throw ProgramRepositoryError.notFound(id: id)
        }
        program.intensityFactor = intensityFactor
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

/// 訓練首頁「今天休息」空狀態（13f 左）用：今天是哪份長期課表的休息日、下一個訓練日是哪天/叫什麼。
public struct ProgramRestDayInfo: Equatable, Sendable {
    /// 這是哪一筆套用的休息日 —— 「把明天的腿日挪到今天」要指定它。
    public let assignmentId: UUID
    public let programName: String
    /// 今天在週期裡的第幾天（1-based，＝設計稿的 `D3`）。
    public let dayNumber: Int
    /// 跑到第幾輪（1-based，repeating 才有意義）；once 模式＝nil，文案就不出現「第 N 輪」。
    public let roundNumber: Int?
    /// 下一個訓練日；nil＝這份套用之後都不會再有訓練日了（once 模式已經跑完週期，且往後沒有訓練日）。
    public let nextWorkoutDate: DayDate?
    public let nextWorkoutName: String?

    public init(
        assignmentId: UUID,
        programName: String,
        dayNumber: Int,
        roundNumber: Int?,
        nextWorkoutDate: DayDate?,
        nextWorkoutName: String?
    ) {
        self.assignmentId = assignmentId
        self.programName = programName
        self.dayNumber = dayNumber
        self.roundNumber = roundNumber
        self.nextWorkoutDate = nextWorkoutDate
        self.nextWorkoutName = nextWorkoutName
    }
}

/// 掃過所有啟用中的長期課表套用，找「今天剛好是休息日」的第一筆。循環課表(Rotation)天生沒有
/// 休息日概念（永遠算「隨時可做」，見 92-known-gaps.md），不在這裡處理。
public struct GetActiveRestDay: Sendable {
    private let programRepository: any ProgramRepository
    private let assignmentRepository: any ProgramAssignmentRepository
    private let today: @Sendable () -> DayDate

    public init(
        programRepository: any ProgramRepository,
        assignmentRepository: any ProgramAssignmentRepository,
        today: @escaping @Sendable () -> DayDate = { DayDate(Date()) }
    ) {
        self.programRepository = programRepository
        self.assignmentRepository = assignmentRepository
        self.today = today
    }

    public func callAsFunction() async throws -> ProgramRestDayInfo? {
        let todayDate = today()
        for assignment in try await assignmentRepository.all() {
            guard let program = try await programRepository.get(id: assignment.programId) else { continue }
            guard let cycleDay = assignment.cycleDay(for: todayDate, cycleLength: program.cycleLength) else { continue }
            guard program.workout(dayIndex: cycleDay) == nil else { continue }   // 今天有排課，不是休息日
            let next = Self.nextWorkout(program: program, assignment: assignment, afterCycleDay: cycleDay, afterDate: todayDate)
            return ProgramRestDayInfo(
                assignmentId: assignment.id,
                programName: program.name,
                dayNumber: cycleDay + 1,
                roundNumber: Self.roundNumber(assignment: assignment, program: program, on: todayDate),
                nextWorkoutDate: next?.date,
                nextWorkoutName: next?.spec.name
            )
        }
        return nil
    }

    /// 跑到第幾輪（1-based）。once 模式只有一輪、不顯示；被 `dayOverrides` 搬過的那天也算不出
    /// 「第幾輪」（它已經不在自然節奏上），一律回 nil 讓文案退成只寫 `D3`。
    private static func roundNumber(assignment: ProgramAssignment, program: Program, on date: DayDate) -> Int? {
        guard assignment.mode == .repeating, assignment.dayOverrides[date] == nil, date >= assignment.startDate
        else { return nil }
        return assignment.startDate.days(to: date) / program.cycleLength + 1
    }

    /// 從 afterCycleDay 的下一天開始找第一個排了 workout 的日子。once 模式最多找到週期結束；
    /// repeating 模式最多繞一圈（整輪都休息理論上不會發生，這裡保底防呆回 nil，不會無限繞）。
    private static func nextWorkout(
        program: Program, assignment: ProgramAssignment, afterCycleDay: Int, afterDate: DayDate
    ) -> (date: DayDate, spec: WorkoutSpec)? {
        let limit = assignment.mode == .once ? program.cycleLength - afterCycleDay - 1 : program.cycleLength
        guard limit > 0 else { return nil }
        for step in 1...limit {
            let cycleDay = (afterCycleDay + step) % program.cycleLength
            if let spec = program.workout(dayIndex: cycleDay) {
                return (afterDate.adding(days: step), spec)
            }
        }
        return nil
    }
}

/// 「把明天的腿日挪到今天」（13f 左）：今天是休息日、想提早練下一個訓練日時用。
///
/// 做法是**把兩天對調**（今天 ↔ 下一個訓練日），寫進 `assignment.dayOverrides`：
/// 今天拿到那天的 cycleDay、那天拿到今天的休息 cycleDay。週期公式本身不動，所以
/// 被搬的兩天以外一切照舊 —— 對應設計稿那句「挪動只影響這一輪，之後的節奏照舊。」
///
/// 只搬「下一個有排課的日子」，不是死板的明天：中間若還有休息日，搬的是再往後那個訓練日
/// （文案本來就寫出它的名字，使用者看得到自己搬的是哪一個）。
public struct MoveNextWorkoutToToday: Sendable {
    private let programRepository: any ProgramRepository
    private let assignmentRepository: any ProgramAssignmentRepository
    private let today: @Sendable () -> DayDate

    public init(
        programRepository: any ProgramRepository,
        assignmentRepository: any ProgramAssignmentRepository,
        today: @escaping @Sendable () -> DayDate = { DayDate(Date()) }
    ) {
        self.programRepository = programRepository
        self.assignmentRepository = assignmentRepository
        self.today = today
    }

    public func callAsFunction(assignmentId: UUID) async throws {
        let todayDate = today()
        guard var assignment = try await assignmentRepository.get(id: assignmentId),
              let program = try await programRepository.get(id: assignment.programId),
              let todayCycleDay = assignment.cycleDay(for: todayDate, cycleLength: program.cycleLength),
              // 今天有排課就沒有「挪過來」這回事，防呆擋掉。
              program.workout(dayIndex: todayCycleDay) == nil
        else { return }

        // 往後找第一個排了 workout 的日子；找不到（往後全休息／once 已到底）就不動。
        let limit = assignment.mode == .once ? program.cycleLength - todayCycleDay - 1 : program.cycleLength
        guard limit > 0 else { return }
        for step in 1...limit {
            let date = todayDate.adding(days: step)
            guard let cycleDay = assignment.cycleDay(for: date, cycleLength: program.cycleLength),
                  program.workout(dayIndex: cycleDay) != nil
            else { continue }
            assignment.dayOverrides[todayDate] = cycleDay
            assignment.dayOverrides[date] = todayCycleDay
            try await assignmentRepository.save(assignment)
            return
        }
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
        // 重設＝回到自然節奏，之前搬過的那幾天要一併清掉，否則會殘留在新週期上。
        assignment.dayOverrides = [:]
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
    /// 已解出的強度倍率（`spec.intensityFactor ?? program.intensityFactor`），
    /// 落地時直接用，不用再查一次 program。
    public let intensityFactor: Double

    public init(
        date: DayDate, assignmentId: UUID, programId: UUID, programName: String, spec: WorkoutSpec,
        intensityFactor: Double = 1.0
    ) {
        self.date = date
        self.assignmentId = assignmentId
        self.programId = programId
        self.programName = programName
        self.spec = spec
        self.intensityFactor = intensityFactor
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
                        programName: program.name, spec: spec,
                        intensityFactor: spec.intensityFactor ?? program.intensityFactor
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
    private let preferences: any TrainingPreferenceStoring
    private let lastPerformedWeightLookup: any LastPerformedWeightLookup
    private let abilityValueLookup: any AbilityValueLookup
    private let makeID: @Sendable () -> UUID

    public init(
        planRepository: any PlanWorkoutRepository,
        preferences: any TrainingPreferenceStoring,
        lastPerformedWeightLookup: any LastPerformedWeightLookup,
        abilityValueLookup: any AbilityValueLookup,
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.planRepository = planRepository
        self.preferences = preferences
        self.lastPerformedWeightLookup = lastPerformedWeightLookup
        self.abilityValueLookup = abilityValueLookup
        self.makeID = makeID
    }

    @discardableResult
    public func callAsFunction(_ projected: ProjectedWorkout) async throws -> PlanWorkout? {
        let onDate = try await planRepository.onDate(projected.date)
        if onDate.contains(where: { $0.assignmentId == projected.assignmentId }) { return nil }
        let orderIndex = (onDate.map(\.orderIndex).max() ?? -1) + 1
        let weightStep = preferences.loadWeightStep()
        let sets = try await resolvedPlanSets(
            from: projected.spec.sets, weightStep: weightStep, intensityFactor: projected.intensityFactor,
            lastPerformedLookup: lastPerformedWeightLookup, abilityValueLookup: abilityValueLookup, makeID: makeID
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
    private let preferences: any TrainingPreferenceStoring
    private let lastPerformedWeightLookup: any LastPerformedWeightLookup
    private let abilityValueLookup: any AbilityValueLookup
    private let makeID: @Sendable () -> UUID

    public init(
        programRepository: any ProgramRepository,
        assignmentRepository: any ProgramAssignmentRepository,
        planRepository: any PlanWorkoutRepository,
        preferences: any TrainingPreferenceStoring,
        lastPerformedWeightLookup: any LastPerformedWeightLookup,
        abilityValueLookup: any AbilityValueLookup,
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.programRepository = programRepository
        self.assignmentRepository = assignmentRepository
        self.planRepository = planRepository
        self.preferences = preferences
        self.lastPerformedWeightLookup = lastPerformedWeightLookup
        self.abilityValueLookup = abilityValueLookup
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
        let weightStep = preferences.loadWeightStep()
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
                        from: spec, on: day, assignmentId: assignment.id, orderIndex: order, weightStep: weightStep,
                        intensityFactor: spec.intensityFactor ?? program.intensityFactor
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
        from spec: WorkoutSpec, on date: DayDate, assignmentId: UUID, orderIndex: Int, weightStep: Double,
        intensityFactor: Double
    ) async throws -> PlanWorkout {
        let sets = try await resolvedPlanSets(
            from: spec.sets, weightStep: weightStep, intensityFactor: intensityFactor,
            lastPerformedLookup: lastPerformedWeightLookup, abilityValueLookup: abilityValueLookup, makeID: makeID
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
