import Foundation
import PlanDomain
import SharedKernel
import Testing

private func restDaySpec(_ name: String) -> WorkoutSpec {
    WorkoutSpec(name: name, sets: [
        PlanSet(id: UUID(), exerciseId: UUID(), exerciseIndex: 0, setIndex: 0,
                targetWeight: .absolute(Weight(value: 60, unit: .kg)), targetReps: 8, restSec: 60),
    ])
}

private func restDayProgram(id: UUID = UUID(), cycleLength: Int, days: [Int: WorkoutSpec]) -> Program {
    Program(id: id, name: "推拉腿", orderIndex: 0, cycleLength: cycleLength, days: days, createdAt: Date(), updatedAt: Date())
}

private let restDayStart = DayDate(year: 2026, month: 7, day: 15)

struct GetActiveRestDayTests {
    private func makeUseCase(
        _ programRepo: MockProgramRepository, _ assignRepo: MockAssignmentRepository, today: DayDate
    ) -> GetActiveRestDay {
        GetActiveRestDay(programRepository: programRepo, assignmentRepository: assignRepo, today: { today })
    }

    @Test func returnsNilWhenTodayHasAWorkout() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let pid = UUID()
        // 3 天週期：第0天推、第1天休、第2天拉；今天是第0天（有排課）。
        await programRepo.seed(restDayProgram(id: pid, cycleLength: 3, days: [0: restDaySpec("推日"), 2: restDaySpec("拉日")]))
        await assignRepo.seed(ProgramAssignment(id: UUID(), programId: pid, startDate: restDayStart, mode: .repeating))
        let useCase = makeUseCase(programRepo, assignRepo, today: restDayStart)

        #expect(try await useCase() == nil)
    }

    @Test func returnsRestDayInfoWithNextWorkoutWhenTodayIsRestDay() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let pid = UUID()
        // 第0天推、第1天休、第2天拉；今天是第1天（休息）。
        await programRepo.seed(restDayProgram(id: pid, cycleLength: 3, days: [0: restDaySpec("推日"), 2: restDaySpec("拉日")]))
        await assignRepo.seed(ProgramAssignment(id: UUID(), programId: pid, startDate: restDayStart, mode: .repeating))
        let today = restDayStart.adding(days: 1)
        let useCase = makeUseCase(programRepo, assignRepo, today: today)

        let info = try await useCase()

        #expect(info?.programName == "推拉腿")
        #expect(info?.nextWorkoutName == "拉日")
        #expect(info?.nextWorkoutDate == today.adding(days: 1))
    }

    @Test func repeatingWrapsAroundToFindNextWorkout() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let pid = UUID()
        // 第0天推、第1天休、第2天休；今天是第2天（休息，往後繞回第0天才有訓練）。
        await programRepo.seed(restDayProgram(id: pid, cycleLength: 3, days: [0: restDaySpec("推日")]))
        await assignRepo.seed(ProgramAssignment(id: UUID(), programId: pid, startDate: restDayStart, mode: .repeating))
        let today = restDayStart.adding(days: 2)
        let useCase = makeUseCase(programRepo, assignRepo, today: today)

        let info = try await useCase()

        #expect(info?.nextWorkoutName == "推日")
        #expect(info?.nextWorkoutDate == today.adding(days: 1))   // 繞回第 0 天＝明天
    }

    @Test func onceModeReturnsNilNextWorkoutWhenNothingLeftInCycle() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let pid = UUID()
        // once 模式，3 天週期：第0天推、第1天休、第2天休（之後沒有訓練日了）。
        await programRepo.seed(restDayProgram(id: pid, cycleLength: 3, days: [0: restDaySpec("推日")]))
        await assignRepo.seed(ProgramAssignment(id: UUID(), programId: pid, startDate: restDayStart, mode: .once))
        let today = restDayStart.adding(days: 1)
        let useCase = makeUseCase(programRepo, assignRepo, today: today)

        let info = try await useCase()

        #expect(info?.programName == "推拉腿")
        #expect(info?.nextWorkoutDate == nil)
        #expect(info?.nextWorkoutName == nil)
    }

    @Test func returnsNilWhenNoActiveAssignments() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let useCase = makeUseCase(programRepo, assignRepo, today: restDayStart)

        #expect(try await useCase() == nil)
    }

    @Test func ignoresAssignmentBeforeItsStartDate() async throws {
        let programRepo = MockProgramRepository()
        let assignRepo = MockAssignmentRepository()
        let pid = UUID()
        await programRepo.seed(restDayProgram(id: pid, cycleLength: 3, days: [0: restDaySpec("推日")]))
        await assignRepo.seed(ProgramAssignment(id: UUID(), programId: pid, startDate: restDayStart, mode: .repeating))
        let useCase = makeUseCase(programRepo, assignRepo, today: restDayStart.adding(days: -1))

        #expect(try await useCase() == nil)
    }
}
