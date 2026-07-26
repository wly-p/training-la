import Foundation
import SharedKernel
import Testing
import TrainingDomain

@testable import TrainingPresentation

private actor MockHomeWorkoutRepo: WorkoutRepository {
    var stored: [UUID: Workout] = [:]
    var active: Workout?
    var saveError: Error?
    var finished: [Workout] = []

    func save(_ workout: Workout) async throws {
        if let saveError { throw saveError }
        stored[workout.id] = workout
    }
    func get(id: UUID) async throws -> Workout? { stored[id] }
    func delete(id: UUID) async throws { stored[id] = nil }
    func activeWorkout() async throws -> Workout? { active }
    func lastPerformance(exerciseId: UUID, excludingWorkout: UUID?) async throws -> [WorkoutSet] { [] }
    func finishedWorkouts() async throws -> [Workout] { finished }
    func exerciseHistory(exerciseId: UUID) async throws -> [ExerciseSetRecord] { [] }
    func usesExercise(_ exerciseId: UUID) async throws -> Bool { false }
}

private actor MockPlannedProvider: PlannedWorkoutProvider {
    let plan: PlannedWorkoutBlueprint?
    var templateList: [PlannedTemplateSummary] = []
    var rotationList: [PlannedRotationSummary] = []
    /// 呼叫紀錄：驗證預覽階段不該碰 startRotation（不動游標），只有 confirm 才碰。
    private(set) var previewRotationCallCount = 0
    private(set) var startRotationCallCount = 0

    init(plan: PlannedWorkoutBlueprint?, templateList: [PlannedTemplateSummary] = [], rotationList: [PlannedRotationSummary] = []) {
        self.plan = plan
        self.templateList = templateList
        self.rotationList = rotationList
    }

    func todaysPlan() async throws -> PlannedWorkoutBlueprint? { plan }
    func blueprint(planWorkoutId: UUID) async throws -> PlannedWorkoutBlueprint? { plan }
    func templates() async throws -> [PlannedTemplateSummary] { templateList }
    func instantiate(templateId: UUID) async throws -> PlannedWorkoutBlueprint? { plan }
    func activeRotations() async throws -> [PlannedRotationSummary] { rotationList }
    func previewRotation(id: UUID) async throws -> PlannedWorkoutBlueprint? {
        previewRotationCallCount += 1
        return plan
    }
    func startRotation(id: UUID) async throws -> PlannedWorkoutBlueprint? {
        startRotationCallCount += 1
        return plan
    }
}

private struct ThrowingPlannedProvider: PlannedWorkoutProvider {
    struct Failure: Error {}
    func todaysPlan() async throws -> PlannedWorkoutBlueprint? { throw Failure() }
    func blueprint(planWorkoutId: UUID) async throws -> PlannedWorkoutBlueprint? { throw Failure() }
    func templates() async throws -> [PlannedTemplateSummary] { throw Failure() }
    func instantiate(templateId: UUID) async throws -> PlannedWorkoutBlueprint? { throw Failure() }
    func activeRotations() async throws -> [PlannedRotationSummary] { throw Failure() }
    func previewRotation(id: UUID) async throws -> PlannedWorkoutBlueprint? { throw Failure() }
    func startRotation(id: UUID) async throws -> PlannedWorkoutBlueprint? { throw Failure() }
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

    @Test func refreshPopulatesActiveRotations() async {
        let repo = MockHomeWorkoutRepo()
        let rotation = PlannedRotationSummary(id: UUID(), rotationName: "推拉腿", currentName: "推日")
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: MockPlannedProvider(plan: nil, rotationList: [rotation])
        )

        await vm.refresh()

        #expect(vm.rotations.map(\.currentName) == ["推日"])
    }

    @Test func startFromRotationCarriesPlanWorkoutId() async {
        let repo = MockHomeWorkoutRepo()
        let plan = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: "推日", targets: [])
        let rotation = PlannedRotationSummary(id: UUID(), rotationName: "推拉腿", currentName: "推日")
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: MockPlannedProvider(plan: plan, rotationList: [rotation])
        )

        await vm.startFromRotation(id: rotation.id)

        #expect(vm.recording?.planWorkoutId == plan.planWorkoutId)
        #expect(vm.errorMessage == nil)
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

    // MARK: - 13d 開練前預覽

    @Test func previewPlanUsesAlreadyLoadedTodaysPlanWithoutStarting() async {
        let repo = MockHomeWorkoutRepo()
        let plan = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: "推日", targets: [])
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: MockPlannedProvider(plan: plan)
        )
        await vm.refresh()

        vm.previewPlan()

        #expect(vm.pendingStart?.source == .plan)
        #expect(vm.pendingStart?.blueprint.planWorkoutId == plan.planWorkoutId)
        #expect(vm.recording == nil)   // 只是預覽，還沒真的開始
    }

    @Test func previewRotationCallsPreviewNotStart() async {
        let repo = MockHomeWorkoutRepo()
        let plan = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: "推日", targets: [])
        let rotationId = UUID()
        let provider = MockPlannedProvider(plan: plan)
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: provider
        )

        await vm.previewRotation(id: rotationId)

        #expect(vm.pendingStart?.source == .rotation(rotationId))
        #expect(await provider.previewRotationCallCount == 1)
        #expect(await provider.startRotationCallCount == 0)   // 關鍵：預覽不該動到游標
        #expect(vm.recording == nil)
    }

    @Test func confirmPendingStartForPlanStartsWorkout() async {
        let repo = MockHomeWorkoutRepo()
        let plan = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: "推日", targets: [])
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: MockPlannedProvider(plan: plan)
        )
        await vm.refresh()
        vm.previewPlan()

        await vm.confirmPendingStart()

        #expect(vm.pendingStart == nil)
        #expect(vm.recording?.planWorkoutId == plan.planWorkoutId)
    }

    @Test func confirmPendingStartForRotationCallsStartExactlyOnce() async {
        let repo = MockHomeWorkoutRepo()
        let plan = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: "推日", targets: [])
        let rotationId = UUID()
        let provider = MockPlannedProvider(plan: plan)
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: provider
        )
        await vm.previewRotation(id: rotationId)

        await vm.confirmPendingStart()

        #expect(vm.pendingStart == nil)
        #expect(vm.recording?.planWorkoutId == plan.planWorkoutId)
        #expect(await provider.startRotationCallCount == 1)   // 真正開始，只在確認那一刻動游標
    }

    @Test func dismissPendingStartClearsPreviewWithoutStarting() async {
        let repo = MockHomeWorkoutRepo()
        let plan = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: "推日", targets: [])
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: MockPlannedProvider(plan: plan)
        )
        await vm.refresh()
        vm.previewPlan()

        vm.dismissPendingStart()

        #expect(vm.pendingStart == nil)
        #expect(vm.recording == nil)
    }
}

private extension MockHomeWorkoutRepo {
    func setActive(_ workout: Workout?) { active = workout }
    func setSaveError(_ error: Error) { saveError = error }
    func setFinished(_ workouts: [Workout]) { finished = workouts }
}

@MainActor
struct TrainingHomeWeekSummaryTests {
    /// 2026/7/26 是週日；週一到週日應該是 7/20～7/26。
    private let monday = DayDate(year: 2026, month: 7, day: 20)
    private let today = DayDate(year: 2026, month: 7, day: 26)

    private func workout(day: DayDate, minutes: Int) -> Workout {
        let start = Date(timeIntervalSince1970: 0)
        return Workout(id: UUID(), day: day, startedAt: start, endedAt: start.addingTimeInterval(Double(minutes) * 60))
    }

    @Test func weekSummaryCountsOnlySessionsWithinMondayToSunday() {
        let finished = [
            workout(day: today, minutes: 40),                      // 這週：週日
            workout(day: monday, minutes: 30),                     // 這週：週一
            workout(day: monday.adding(days: -1), minutes: 999),   // 上週日，不算
        ]

        let summary = TrainingHomeViewModel.weekSummary(from: finished, today: today)

        #expect(summary.sessionCount == 2)
        #expect(summary.totalMinutes == 70)
        #expect(summary.days.count == 7)
        #expect(summary.days.first?.date == monday)
        #expect(summary.days.last?.date == today)
    }

    @Test func weekSummaryMarksCompletedAndTodayCorrectly() {
        let finished = [workout(day: monday, minutes: 10)]

        let summary = TrainingHomeViewModel.weekSummary(from: finished, today: today)

        #expect(summary.days.first { $0.date == monday }?.completed == true)
        #expect(summary.days.first { $0.date == today }?.isToday == true)
        #expect(summary.days.filter(\.completed).count == 1)
    }

    @Test func refreshPopulatesLastSessionNameFromBlueprint() async {
        let repo = MockHomeWorkoutRepo()
        let planWorkoutId = UUID()
        let workout = Workout(id: UUID(), day: today, planWorkoutId: planWorkoutId,
                               startedAt: Date(), endedAt: Date())
        await repo.setFinished([workout])
        let plan = PlannedWorkoutBlueprint(planWorkoutId: planWorkoutId, name: "胸日", targets: [])
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            recentWorkouts: RecentWorkouts(repository: repo),
            plannedProvider: MockPlannedProvider(plan: plan)
        )

        await vm.refresh()

        #expect(vm.lastSession?.name == "胸日")
        #expect(vm.weekSummary != nil)
    }

    @Test func refreshLeavesLastSessionNilWhenNeverTrained() async {
        let repo = MockHomeWorkoutRepo()
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            recentWorkouts: RecentWorkouts(repository: repo)
        )

        await vm.refresh()

        #expect(vm.lastSession == nil)
    }
}
