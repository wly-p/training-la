import Foundation
import SharedKernel
import Testing
import TrainingDomain

@testable import TrainingPresentation

private actor MockHomeWorkoutRepo: WorkoutRepository {
    var stored: [UUID: Workout] = [:]
    var active: Workout?
    var saveError: Error?

    func save(_ workout: Workout) async throws {
        if let saveError { throw saveError }
        stored[workout.id] = workout
    }
    func get(id: UUID) async throws -> Workout? { stored[id] }
    func delete(id: UUID) async throws { stored[id] = nil }
    func activeWorkout() async throws -> Workout? { active }
    func lastPerformance(exerciseId: UUID, excludingWorkout: UUID?) async throws -> [WorkoutSet] { [] }
    func finishedWorkouts() async throws -> [Workout] { [] }
    func exerciseHistory(exerciseId: UUID) async throws -> [ExerciseSetRecord] { [] }
    func usesExercise(_ exerciseId: UUID) async throws -> Bool { false }
}

private struct MockPlannedProvider: PlannedWorkoutProvider {
    let plan: PlannedWorkoutBlueprint?
    func todaysPlan() async throws -> PlannedWorkoutBlueprint? { plan }
    func blueprint(planWorkoutId: UUID) async throws -> PlannedWorkoutBlueprint? { plan }
}

private struct ThrowingPlannedProvider: PlannedWorkoutProvider {
    struct Failure: Error {}
    func todaysPlan() async throws -> PlannedWorkoutBlueprint? { throw Failure() }
    func blueprint(planWorkoutId: UUID) async throws -> PlannedWorkoutBlueprint? { throw Failure() }
}

@MainActor
struct TrainingHomeViewModelTests {
    @Test func refreshPopulatesResumableAndTodaysPlan() async {
        let repo = MockHomeWorkoutRepo()
        let activeWorkout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 11), startedAt: Date())
        await repo.setActive(activeWorkout)
        let plan = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: "推日", targets: [])
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: MockPlannedProvider(plan: plan)
        )

        await vm.refresh()

        #expect(vm.resumable == activeWorkout)
        #expect(vm.todaysPlan?.planWorkoutId == plan.planWorkoutId)
        #expect(vm.errorMessage == nil)
    }

    @Test func refreshSetsErrorMessageWhenPlannedProviderThrows() async {
        let repo = MockHomeWorkoutRepo()
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: ThrowingPlannedProvider()
        )

        await vm.refresh()

        #expect(vm.errorMessage != nil)
    }

    @Test func startFreeBeginsWorkoutWithoutPlanWorkoutId() async {
        let repo = MockHomeWorkoutRepo()
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo)
        )

        await vm.startFree()

        #expect(vm.recording?.planWorkoutId == nil)
        #expect(vm.errorMessage == nil)
    }

    @Test func startFromPlanCarriesTodaysPlanWorkoutId() async {
        let repo = MockHomeWorkoutRepo()
        let plan = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: "推日", targets: [])
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: MockPlannedProvider(plan: plan)
        )
        await vm.refresh()

        await vm.startFromPlan()

        #expect(vm.recording?.planWorkoutId == plan.planWorkoutId)
    }

    @Test func resumeAssignsResumableToRecording() async {
        let repo = MockHomeWorkoutRepo()
        let activeWorkout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 11), startedAt: Date())
        await repo.setActive(activeWorkout)
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo)
        )
        await vm.refresh()

        vm.resume()

        #expect(vm.recording == activeWorkout)
    }

    @Test func startFreeSetsErrorMessageWhenSaveFails() async {
        struct SaveFailure: Error {}
        let repo = MockHomeWorkoutRepo()
        await repo.setSaveError(SaveFailure())
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo)
        )

        await vm.startFree()

        #expect(vm.errorMessage != nil)
        #expect(vm.recording == nil)
    }

    @Test func dismissErrorClearsErrorMessage() async {
        let repo = MockHomeWorkoutRepo()
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: ThrowingPlannedProvider()
        )
        await vm.refresh()
        #expect(vm.errorMessage != nil)

        vm.dismissError()

        #expect(vm.errorMessage == nil)
    }
}

private extension MockHomeWorkoutRepo {
    func setActive(_ workout: Workout?) { active = workout }
    func setSaveError(_ error: Error) { saveError = error }
}
