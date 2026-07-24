import Foundation
import PlanDomain
import SharedKernel
import SwiftData
import Testing

@testable import PlanData

struct SwiftDataProgramRepositoryTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(PlanDataFactory.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func spec(_ name: String, exercise: UUID = UUID()) -> WorkoutSpec {
        WorkoutSpec(name: name, sets: [
            PlanSet(id: UUID(), exerciseId: exercise, exerciseIndex: 0, setIndex: 0,
                    targetWeight: Weight(value: 100, unit: .kg), targetReps: 5, restSec: 90),
        ])
    }

    private func program(id: UUID = UUID(), cycleLength: Int, days: [Int: WorkoutSpec]) -> Program {
        Program(id: id, name: "PPL", orderIndex: 0, cycleLength: cycleLength, days: days, createdAt: Date(), updatedAt: Date())
    }

    @Test func saveThenGetReconstructsCycleDays() async throws {
        let container = try makeContainer()
        let repo = PlanDataFactory.makeProgramRepository(container: container)
        let id = UUID()
        // 10 天週期，第0推、第2拉、第5腿
        try await repo.save(program(id: id, cycleLength: 10, days: [0: spec("推"), 2: spec("拉"), 5: spec("腿")]))

        let p = try await repo.get(id: id)!
        #expect(p.cycleLength == 10)
        #expect(p.workout(dayIndex: 0)?.name == "推")
        #expect(p.workout(dayIndex: 1) == nil)      // 休息日
        #expect(p.workout(dayIndex: 2)?.name == "拉")
        #expect(p.workout(dayIndex: 5)?.name == "腿")
        #expect(p.workout(dayIndex: 10) == nil)     // 超界
    }

    @Test func saveUpsertsAndAllSortsByOrderIndex() async throws {
        let container = try makeContainer()
        let repo = PlanDataFactory.makeProgramRepository(container: container)
        try await repo.save(Program(id: UUID(), name: "B", orderIndex: 1, cycleLength: 7, createdAt: Date(), updatedAt: Date()))
        let aid = UUID()
        try await repo.save(Program(id: aid, name: "A", orderIndex: 0, cycleLength: 7, createdAt: Date(), updatedAt: Date()))
        try await repo.save(program(id: aid, cycleLength: 5, days: [0: spec("胸")]))   // upsert（program() 名稱＝PPL）

        let all = try await repo.all()
        #expect(all.map(\.name) == ["PPL", "B"])   // A→PPL、排序 by orderIndex(0,1)
        #expect(all.count == 2)
        #expect(all.first?.cycleLength == 5)
    }

    @Test func usesExerciseReflectsSlotSets() async throws {
        let container = try makeContainer()
        let repo = PlanDataFactory.makeProgramRepository(container: container)
        let used = UUID()
        try await repo.save(program(cycleLength: 5, days: [0: spec("推", exercise: used)]))

        #expect(try await repo.usesExercise(used) == true)
        #expect(try await repo.usesExercise(UUID()) == false)
    }

    @Test func assignmentRoundTripsAndForProgramFilters() async throws {
        let container = try makeContainer()
        let repo = PlanDataFactory.makeProgramAssignmentRepository(container: container)
        let pid = UUID()
        let aid = UUID()
        try await repo.save(ProgramAssignment(
            id: aid, programId: pid, startDate: DayDate(year: 2026, month: 7, day: 20),
            mode: .repeating, lastReconciledDate: DayDate(year: 2026, month: 7, day: 22)
        ))
        try await repo.save(ProgramAssignment(id: UUID(), programId: UUID(), startDate: DayDate(year: 2026, month: 7, day: 1), mode: .once))

        let a = try await repo.get(id: aid)!
        #expect(a.programId == pid)
        #expect(a.mode == .repeating)
        #expect(a.startDate == DayDate(year: 2026, month: 7, day: 20))
        #expect(a.lastReconciledDate == DayDate(year: 2026, month: 7, day: 22))
        #expect(try await repo.forProgram(pid).map(\.id) == [aid])
        #expect(try await repo.all().count == 2)
    }
}
