import Testing

@testable import SharedKernel

struct StatusesTests {
    @Test func workoutSetStatusRawValuesMatchApiContract() {
        #expect(WorkoutSetStatus.done.rawValue == "done")
        #expect(WorkoutSetStatus.skipped.rawValue == "skipped")
        #expect(WorkoutSetStatus.interrupted.rawValue == "interrupted")
    }

    @Test func planWorkoutStatusRawValuesMatchApiContract() {
        #expect(PlanWorkoutStatus.notStarted.rawValue == "not_started")
        #expect(PlanWorkoutStatus.done.rawValue == "done")
        #expect(PlanWorkoutStatus.skipped.rawValue == "skipped")
    }

    @Test func allCasesAreCovered() {
        #expect(WorkoutSetStatus.allCases.count == 3)
        #expect(PlanWorkoutStatus.allCases.count == 3)
    }
}
