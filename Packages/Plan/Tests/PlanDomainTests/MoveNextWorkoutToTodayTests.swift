import Foundation
import PlanDomain
import SharedKernel
import Testing

private func moveSpec(_ name: String) -> WorkoutSpec {
    WorkoutSpec(name: name, sets: [
        PlanSet(id: UUID(), exerciseId: UUID(), exerciseIndex: 0, setIndex: 0,
                targetWeight: .absolute(Weight(value: 60, unit: .kg)), targetReps: 8, restSec: 60),
    ])
}

private func moveProgram(id: UUID, cycleLength: Int, days: [Int: WorkoutSpec]) -> Program {
    Program(id: id, name: "推拉腿", orderIndex: 0, cycleLength: cycleLength, days: days,
            createdAt: Date(), updatedAt: Date())
}

private let moveStart = DayDate(year: 2026, month: 7, day: 15)

/// 「把明天的腿日挪到今天」（13f 左）。重點是**只有被搬的那兩天變**，其餘節奏照舊。
struct MoveNextWorkoutToTodayTests {
    /// 第0天推、第1天休、第2天拉；今天站在第1天（休息）。
    private func seedThreeDayCycle(
        _ programRepo: MockProgramRepository, _ assignRepo: MockAssignmentRepository,
        mode: ProgramRunMode = .repeating
    ) async -> (assignmentId: UUID, programId: UUID) {
        let pid = UUID()
        let aid = UUID()
        await programRepo.seed(moveProgram(id: pid, cycleLength: 3,
                                           days: [0: moveSpec("推日"), 2: moveSpec("拉日")]))
        await assignRepo.seed(ProgramAssignment(id: aid, programId: pid, startDate: moveStart, mode: mode))
        return (aid, pid)
    }

    @Test func swapsTodayWithNextWorkoutDay() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let (aid, _) = await seedThreeDayCycle(programRepo, assignRepo)
        let today = moveStart.adding(days: 1)   // 第1天＝休息
        let useCase = MoveNextWorkoutToToday(
            programRepository: programRepo, assignmentRepository: assignRepo, today: { today }
        )

        try await useCase(assignmentId: aid)

        let saved = try #require(try await assignRepo.get(id: aid))
        // 今天拿到「拉日」那天的 cycleDay（2），明天拿到今天原本的休息 cycleDay（1）。
        #expect(saved.cycleDay(for: today, cycleLength: 3) == 2)
        #expect(saved.cycleDay(for: today.adding(days: 1), cycleLength: 3) == 1)
    }

    @Test func laterDaysKeepTheirOriginalRhythm() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let (aid, _) = await seedThreeDayCycle(programRepo, assignRepo)
        let today = moveStart.adding(days: 1)
        let useCase = MoveNextWorkoutToToday(
            programRepository: programRepo, assignmentRepository: assignRepo, today: { today }
        )

        try await useCase(assignmentId: aid)

        let saved = try #require(try await assignRepo.get(id: aid))
        // 被搬的兩天之外一律照週期公式：第3天回到 cycleDay 0、第4天 1、第5天 2……
        for step in 2...5 {
            let date = today.adding(days: step)
            #expect(saved.cycleDay(for: date, cycleLength: 3) == (1 + step) % 3)
        }
    }

    @Test func doesNothingWhenTodayAlreadyHasAWorkout() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let (aid, _) = await seedThreeDayCycle(programRepo, assignRepo)
        let useCase = MoveNextWorkoutToToday(
            programRepository: programRepo, assignmentRepository: assignRepo, today: { moveStart }
        )

        try await useCase(assignmentId: aid)

        let saved = try #require(try await assignRepo.get(id: aid))
        #expect(saved.dayOverrides.isEmpty)
    }

    @Test func doesNothingWhenOnceModeHasNoWorkoutLeft() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let pid = UUID()
        let aid = UUID()
        // once 模式、3 天週期，只有第0天有排課 → 站在第1天時往後已經沒有訓練日。
        await programRepo.seed(moveProgram(id: pid, cycleLength: 3, days: [0: moveSpec("推日")]))
        await assignRepo.seed(ProgramAssignment(id: aid, programId: pid, startDate: moveStart, mode: .once))
        let useCase = MoveNextWorkoutToToday(
            programRepository: programRepo, assignmentRepository: assignRepo,
            today: { moveStart.adding(days: 1) }
        )

        try await useCase(assignmentId: aid)

        let saved = try #require(try await assignRepo.get(id: aid))
        #expect(saved.dayOverrides.isEmpty)
    }

    @Test func restDayInfoReflectsTheSwapAndDropsRoundNumber() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let (aid, _) = await seedThreeDayCycle(programRepo, assignRepo)
        let today = moveStart.adding(days: 1)
        try await MoveNextWorkoutToToday(
            programRepository: programRepo, assignmentRepository: assignRepo, today: { today }
        )(assignmentId: aid)

        // 挪完今天就有排課了 → 不再是休息日。
        let restDayToday = try await GetActiveRestDay(
            programRepository: programRepo, assignmentRepository: assignRepo, today: { today }
        )()
        #expect(restDayToday == nil)

        // 明天變成休息日；那天已被搬過，算不出「第幾輪」，文案要退成只寫 D 幾。
        let restDayTomorrow = try await GetActiveRestDay(
            programRepository: programRepo, assignmentRepository: assignRepo,
            today: { today.adding(days: 1) }
        )()
        #expect(restDayTomorrow?.dayNumber == 2)
        #expect(restDayTomorrow?.roundNumber == nil)
    }

    @Test func resetProgressClearsOverrides() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let (aid, pid) = await seedThreeDayCycle(programRepo, assignRepo)
        let today = moveStart.adding(days: 1)
        try await MoveNextWorkoutToToday(
            programRepository: programRepo, assignmentRepository: assignRepo, today: { today }
        )(assignmentId: aid)

        try await ResetProgramProgress(repository: assignRepo)(programId: pid, today: today)

        let saved = try #require(try await assignRepo.get(id: aid))
        #expect(saved.dayOverrides.isEmpty)
    }
}
