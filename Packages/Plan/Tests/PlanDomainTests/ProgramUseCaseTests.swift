import Foundation
import PlanDomain
import SharedKernel
import Testing

// MARK: - Mocks

actor MockProgramRepository: ProgramRepository {
    private var stored: [UUID: Program] = [:]
    func seed(_ p: Program) { stored[p.id] = p }
    func all() async throws -> [Program] { stored.values.sorted { $0.orderIndex < $1.orderIndex } }
    func get(id: UUID) async throws -> Program? { stored[id] }
    func save(_ program: Program) async throws { stored[program.id] = program }
    func delete(id: UUID) async throws { stored[id] = nil }
    func usesExercise(_ exerciseId: UUID) async throws -> Bool {
        stored.values.contains { $0.days.values.contains { $0.sets.contains { $0.exerciseId == exerciseId } } }
    }
}

actor MockAssignmentRepository: ProgramAssignmentRepository {
    private var stored: [UUID: ProgramAssignment] = [:]
    func seed(_ a: ProgramAssignment) { stored[a.id] = a }
    func all() async throws -> [ProgramAssignment] { Array(stored.values) }
    func get(id: UUID) async throws -> ProgramAssignment? { stored[id] }
    func save(_ assignment: ProgramAssignment) async throws { stored[assignment.id] = assignment }
    func delete(id: UUID) async throws { stored[id] = nil }
    func forProgram(_ programId: UUID) async throws -> [ProgramAssignment] {
        stored.values.filter { $0.programId == programId }
    }
}

// MARK: - Helpers

private func spec(_ name: String, exercise: UUID = UUID()) -> WorkoutSpec {
    WorkoutSpec(name: name, sets: [
        PlanSet(id: UUID(), exerciseId: exercise, exerciseIndex: 0, setIndex: 0,
                targetWeight: Weight(value: 60, unit: .kg), targetReps: 8, restSec: 60),
    ])
}

private func program(id: UUID = UUID(), cycleLength: Int, days: [Int: WorkoutSpec]) -> Program {
    Program(id: id, name: "課表", orderIndex: 0, cycleLength: cycleLength, days: days, createdAt: Date(), updatedAt: Date())
}

private let start = DayDate(year: 2026, month: 7, day: 15)

// MARK: - cycleDay 週期對位

struct ProgramCycleDayTests {
    @Test func offsetFromStartIgnoringWeekday() {
        let a = ProgramAssignment(id: UUID(), programId: UUID(), startDate: start, mode: .once)
        #expect(a.cycleDay(for: start, cycleLength: 5) == 0)
        #expect(a.cycleDay(for: start.adding(days: 3), cycleLength: 5) == 3)
        #expect(a.cycleDay(for: start.adding(days: 4), cycleLength: 5) == 4)
    }

    @Test func beforeStartIsNil() {
        let a = ProgramAssignment(id: UUID(), programId: UUID(), startDate: start, mode: .once)
        #expect(a.cycleDay(for: start.adding(days: -1), cycleLength: 5) == nil)
    }

    @Test func onceEndsAfterCycleLength() {
        let a = ProgramAssignment(id: UUID(), programId: UUID(), startDate: start, mode: .once)
        #expect(a.cycleDay(for: start.adding(days: 5), cycleLength: 5) == nil)   // 第 6 天
    }

    @Test func repeatingWrapsAround() {
        let a = ProgramAssignment(id: UUID(), programId: UUID(), startDate: start, mode: .repeating)
        #expect(a.cycleDay(for: start.adding(days: 5), cycleLength: 5) == 0)      // 5 % 5
        #expect(a.cycleDay(for: start.adding(days: 12), cycleLength: 5) == 2)     // 12 % 5
    }

    @Test func supportsNonSevenDayCycles() {
        // 10 天課表
        let a = ProgramAssignment(id: UUID(), programId: UUID(), startDate: start, mode: .repeating)
        #expect(a.cycleDay(for: start.adding(days: 9), cycleLength: 10) == 9)
        #expect(a.cycleDay(for: start.adding(days: 10), cycleLength: 10) == 0)
    }
}

// MARK: - 投影

struct ProjectScheduleTests {
    private func makeProject(
        _ programRepo: MockProgramRepository,
        _ assignRepo: MockAssignmentRepository,
        _ planRepo: MockPlanWorkoutRepository
    ) -> ProjectSchedule {
        ProjectSchedule(programRepository: programRepo, assignmentRepository: assignRepo, planRepository: planRepo)
    }

    @Test func projectsFutureScheduledDays() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let planRepo = MockPlanWorkoutRepository()
        let pid = UUID()
        // 3 天週期：第0天推、第1天休、第2天拉
        await programRepo.seed(program(id: pid, cycleLength: 3, days: [0: spec("推"), 2: spec("拉")]))
        let aid = UUID()
        await assignRepo.seed(ProgramAssignment(id: aid, programId: pid, startDate: start, mode: .repeating))

        // 6 天範圍：推、拉、推、拉（第1、4天休息 → 略過）
        let projected = try await makeProject(programRepo, assignRepo, planRepo)(
            from: start, to: start.adding(days: 5), today: start
        )
        #expect(projected.map(\.spec.name) == ["推", "拉", "推", "拉"])
        #expect(projected.map { $0.date } == [start, start.adding(days: 2), start.adding(days: 3), start.adding(days: 5)])
        #expect(projected.allSatisfy { $0.assignmentId == aid })
    }

    @Test func skipsPastAndAlreadyMaterialized() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let planRepo = MockPlanWorkoutRepository()
        let pid = UUID()
        await programRepo.seed(program(id: pid, cycleLength: 3, days: [0: spec("推")]))
        let aid = UUID()
        await assignRepo.seed(ProgramAssignment(id: aid, programId: pid, startDate: start, mode: .repeating))
        // 已落地一筆真實排課在「第 3 天」（下一輪第 0 天）
        let nextCycle = start.adding(days: 3)
        await planRepo.seed([PlanWorkout(
            id: UUID(), name: "推", date: nextCycle, origin: .program, assignmentId: aid, orderIndex: 0
        )])

        // today = 起始日+1 → 起始日（過去）不投影；第 3 天已落地 → 不投影
        let today = start.adding(days: 1)
        let projected = try await makeProject(programRepo, assignRepo, planRepo)(
            from: start, to: start.adding(days: 5), today: today
        )
        #expect(projected.isEmpty)
    }
}

// MARK: - 補登

struct ReconcileProgramAssignmentsTests {
    private func makeReconcile(
        _ programRepo: MockProgramRepository,
        _ assignRepo: MockAssignmentRepository,
        _ planRepo: MockPlanWorkoutRepository
    ) -> ReconcileProgramAssignments {
        ReconcileProgramAssignments(programRepository: programRepo, assignmentRepository: assignRepo, planRepository: planRepo)
    }

    @Test func materializesPastDaysAsNotStarted() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let planRepo = MockPlanWorkoutRepository()
        let pid = UUID()
        await programRepo.seed(program(id: pid, cycleLength: 3, days: [0: spec("推"), 2: spec("拉")]))
        let aid = UUID()
        await assignRepo.seed(ProgramAssignment(id: aid, programId: pid, startDate: start, mode: .repeating))

        // today = 起始日+3 → 掃 [start … start+2]：第0天推、第2天拉（第1天休息）
        let today = start.adding(days: 3)
        let created = try await makeReconcile(programRepo, assignRepo, planRepo)(today: today)

        #expect(created == 2)
        let all = try await planRepo.all()
        #expect(all.count == 2)
        #expect(all.allSatisfy { $0.origin == .program && $0.assignmentId == aid && $0.status == .notStarted })
        #expect(try await planRepo.onDate(today).isEmpty)   // 今天（第3天）不補
        #expect(try await assignRepo.get(id: aid)?.lastReconciledDate == today.adding(days: -1))
    }

    @Test func isIdempotentOnSecondRun() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let planRepo = MockPlanWorkoutRepository()
        let pid = UUID()
        await programRepo.seed(program(id: pid, cycleLength: 5, days: [0: spec("推")]))
        let aid = UUID()
        await assignRepo.seed(ProgramAssignment(id: aid, programId: pid, startDate: start, mode: .repeating))
        let today = start.adding(days: 10)     // 掃到第 9 天 → 第0、第5天各一次
        let reconcile = makeReconcile(programRepo, assignRepo, planRepo)

        let first = try await reconcile(today: today)
        let second = try await reconcile(today: today)

        #expect(first == 2)
        #expect(second == 0)
        #expect(try await planRepo.all().count == 2)
    }

    @Test func doesNotMaterializeBeforeStart() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let planRepo = MockPlanWorkoutRepository()
        let pid = UUID()
        await programRepo.seed(program(id: pid, cycleLength: 3, days: [0: spec("推")]))
        let aid = UUID()
        await assignRepo.seed(ProgramAssignment(id: aid, programId: pid, startDate: start.adding(days: 7), mode: .once))

        let created = try await makeReconcile(programRepo, assignRepo, planRepo)(today: start.adding(days: 3))

        #expect(created == 0)
        #expect(try await planRepo.all().isEmpty)
    }
}
