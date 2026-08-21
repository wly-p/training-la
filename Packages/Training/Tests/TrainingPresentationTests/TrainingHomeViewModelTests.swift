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
    /// 從 `stored` 動態查，不是直接回傳 `active` 這個固定值——這樣 `finishWorkout`/`discardWorkout`
    /// 對 `stored` 的實際改動（save 出 isFinished、或 delete 掉）才會反映在下一次 `refresh()`。
    func activeWorkout() async throws -> Workout? {
        guard let active, let current = stored[active.id], !current.isFinished else { return nil }
        return current
    }
    func lastPerformance(exerciseId: UUID, excludingWorkout: UUID?) async throws -> [WorkoutSet] { [] }
    func finishedWorkouts(limit: Int?) async throws -> [Workout] {
        // 上限也要照做，否則 mock 會把「首頁只取最近 N 場」這個行為藏起來。
        limit.map { Array(finished.prefix($0)) } ?? finished
    }
    func exerciseHistory(exerciseId: UUID) async throws -> [ExerciseSetRecord] { [] }
    func usesExercise(_ exerciseId: UUID) async throws -> Bool { false }
}

private actor MockPlannedProvider: PlannedWorkoutProvider {
    let plan: PlannedWorkoutBlueprint?
    var templateList: [PlannedTemplateSummary] = []
    var rotationList: [PlannedRotationSummary] = []
    var restDay: RestDayInfo?
    /// 呼叫紀錄：驗證預覽階段不該碰 startRotation（不動游標），只有 confirm 才碰。
    private(set) var previewRotationCallCount = 0
    private(set) var startRotationCallCount = 0
    /// 呼叫紀錄：驗證有「今天指定」排課時不該再查休息日（兩者互斥）。
    private(set) var activeRestDayCallCount = 0
    /// 呼叫紀錄：驗證「把明天的腿日挪到今天」有真的打到 Plan 那一側。
    private(set) var moveNextWorkoutCallCount = 0

    init(
        plan: PlannedWorkoutBlueprint?,
        templateList: [PlannedTemplateSummary] = [],
        rotationList: [PlannedRotationSummary] = [],
        restDay: RestDayInfo? = nil
    ) {
        self.plan = plan
        self.templateList = templateList
        self.rotationList = rotationList
        self.restDay = restDay
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
    func activeRestDay() async throws -> RestDayInfo? {
        activeRestDayCallCount += 1
        return restDay
    }
    func moveNextWorkoutToToday() async throws {
        moveNextWorkoutCallCount += 1
        restDay = nil
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
    func activeRestDay() async throws -> RestDayInfo? { throw Failure() }
    func moveNextWorkoutToToday() async throws { throw Failure() }
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

    @Test func refreshPopulatesRestDayWhenNoTodaysPlan() async {
        let repo = MockHomeWorkoutRepo()
        let restDay = RestDayInfo(
            programName: "推拉腿", dayNumber: 3, roundNumber: 7,
            nextWorkoutDate: DayDate(year: 2026, month: 7, day: 28), nextWorkoutName: "腿日"
        )
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: MockPlannedProvider(plan: nil, restDay: restDay)
        )

        await vm.refresh()

        #expect(vm.restDay == restDay)
    }

    @Test func refreshSkipsRestDayQueryWhenTodaysPlanExists() async {
        let repo = MockHomeWorkoutRepo()
        let plan = PlannedWorkoutBlueprint(planWorkoutId: UUID(), name: "推日", targets: [])
        let restDay = RestDayInfo(
            programName: "推拉腿", dayNumber: 3, roundNumber: nil, nextWorkoutDate: nil, nextWorkoutName: nil
        )
        let provider = MockPlannedProvider(plan: plan, restDay: restDay)
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: provider
        )

        await vm.refresh()

        #expect(vm.restDay == nil)
        #expect(await provider.activeRestDayCallCount == 0)
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

    // MARK: - 13b 中斷後恢復

    @Test func resumeSummaryMarksOvernightWhenWorkoutDayIsNotToday() async {
        let repo = MockHomeWorkoutRepo()
        let yesterday = DayDate(year: 2026, month: 7, day: 26)
        let today = DayDate(year: 2026, month: 7, day: 27)
        let active = Workout(id: UUID(), day: yesterday, startedAt: Date(timeIntervalSince1970: 0))
        await repo.setActive(active)
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            today: { today }
        )

        await vm.refresh()

        #expect(vm.resumeSummary?.isOvernight == true)
    }

    @Test func resumeSummaryNotOvernightWhenSameDay() async {
        let repo = MockHomeWorkoutRepo()
        let today = DayDate(year: 2026, month: 7, day: 27)
        let active = Workout(id: UUID(), day: today, startedAt: Date())
        await repo.setActive(active)
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            today: { today }
        )

        await vm.refresh()

        #expect(vm.resumeSummary?.isOvernight == false)
    }

    @Test func resumeSummaryComputesRemainingSetsFromBlueprint() async {
        let repo = MockHomeWorkoutRepo()
        let planWorkoutId = UUID()
        let exerciseId = UUID()
        let active = Workout(
            id: UUID(), day: DayDate(year: 2026, month: 7, day: 27), planWorkoutId: planWorkoutId,
            startedAt: Date(),
            sets: [WorkoutSet(id: UUID(), exerciseId: exerciseId, exerciseIndex: 0, setIndex: 0,
                              weight: Weight(value: 60, unit: .kg), reps: 8)]
        )
        await repo.setActive(active)
        let targets = (0..<3).map { i in
            PlannedTargetSet(id: UUID(), exerciseId: exerciseId, exerciseName: "臥推",
                             exerciseIndex: 0, setIndex: i, targetWeight: Weight(value: 60, unit: .kg),
                             targetReps: 8, restSec: nil)
        }
        let blueprint = PlannedWorkoutBlueprint(planWorkoutId: planWorkoutId, name: "推日", targets: targets)
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: MockPlannedProvider(plan: blueprint)
        )

        await vm.refresh()

        #expect(vm.resumeSummary?.name == "推日")
        #expect(vm.resumeSummary?.recordedSetCount == 1)
        #expect(vm.resumeSummary?.remainingSetCount == 2)
    }

    @Test func resumeSummaryRemainingSetsNilForFreeTraining() async {
        let repo = MockHomeWorkoutRepo()
        let active = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 27), startedAt: Date())
        await repo.setActive(active)
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo)
        )

        await vm.refresh()

        #expect(vm.resumeSummary?.remainingSetCount == nil)
    }

    @Test func endResumableNowFinishesAndClearsResumable() async {
        let repo = MockHomeWorkoutRepo()
        let active = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 27), startedAt: Date())
        await repo.setActive(active)
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            finishWorkout: FinishWorkout(repository: repo)
        )
        await vm.refresh()
        #expect(vm.resumable != nil)

        await vm.endResumableNow()

        #expect(vm.resumable == nil)
        #expect(vm.resumeSummary == nil)
        let saved = (try? await repo.get(id: active.id)) ?? nil
        #expect(saved?.isFinished == true)
    }

    @Test func discardResumableDeletesAndClearsResumable() async {
        let repo = MockHomeWorkoutRepo()
        let active = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 27), startedAt: Date())
        await repo.setActive(active)
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            discardWorkout: DiscardWorkout(repository: repo)
        )
        await vm.refresh()

        await vm.discardResumable()

        #expect(vm.resumable == nil)
        let stillThere = try? await repo.get(id: active.id)
        #expect((stillThere ?? nil) == nil)
    }
}

private extension MockHomeWorkoutRepo {
    func setActive(_ workout: Workout?) {
        active = workout
        if let workout { stored[workout.id] = workout }
    }
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

        let summary = TrainingHomeViewModel.weekSummary(from: finished, today: today, firstWeekday: 2)

        #expect(summary.sessionCount == 2)
        #expect(summary.totalMinutes == 70)
        #expect(summary.days.count == 7)
        #expect(summary.days.first?.date == monday)
        #expect(summary.days.last?.date == today)
    }

    /// 週日起算的地區（美國等）：2026/7/26 本身就是週日，這一週應該是 7/26～8/1，
    /// 上一支測試裡「這週的週一 7/20」在這個地區反而落在上一週。
    @Test func weekSummaryRespectsSundayFirstWeekday() {
        let finished = [
            workout(day: today, minutes: 40),    // 7/26 週日＝這週第一天
            workout(day: monday, minutes: 30),   // 7/20 週一＝上一週，不算
        ]

        let summary = TrainingHomeViewModel.weekSummary(from: finished, today: today, firstWeekday: 1)

        #expect(summary.sessionCount == 1)
        #expect(summary.totalMinutes == 40)
        #expect(summary.days.first?.date == today)
        #expect(summary.days.last?.date == DayDate(year: 2026, month: 8, day: 1))
    }

    @Test func weekSummaryMarksCompletedAndTodayCorrectly() {
        let finished = [workout(day: monday, minutes: 10)]

        let summary = TrainingHomeViewModel.weekSummary(from: finished, today: today, firstWeekday: 2)

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

    /// 13f 左的綠卡要寫「這週已經練了 3 次、9,140 kg」，總量只算 `.done` 的組、且先換算成公斤。
    @Test func weekSummarySumsVolumeInKilogramsAcrossThisWeek() {
        func set(_ weight: Weight, reps: Int, status: WorkoutSetStatus = .done) -> WorkoutSet {
            WorkoutSet(id: UUID(), exerciseId: UUID(), exerciseIndex: 0, setIndex: 0,
                       weight: weight, reps: reps, status: status)
        }
        let thisWeek = Workout(id: UUID(), day: monday, sets: [
            set(Weight(value: 100, unit: .kg), reps: 5),                     // 500
            set(Weight(value: 100, unit: .kg), reps: 5, status: .skipped),   // 跳過的不算
        ])
        let lastWeek = Workout(id: UUID(), day: monday.adding(days: -1), sets: [
            set(Weight(value: 100, unit: .kg), reps: 10),                    // 上週，不算
        ])

        let summary = TrainingHomeViewModel.weekSummary(from: [thisWeek, lastWeek], today: today, firstWeekday: 2)

        #expect(summary.totalVolume == 500)
    }

    @Test func recentSessionsListsNamedSessionsNewestFirst() async {
        let repo = MockHomeWorkoutRepo()
        let planWorkoutId = UUID()
        let start = Date(timeIntervalSince1970: 0)
        let workout = Workout(id: UUID(), day: today, planWorkoutId: planWorkoutId,
                              startedAt: start, endedAt: start.addingTimeInterval(72 * 60))
        await repo.setFinished([workout])
        let plan = PlannedWorkoutBlueprint(planWorkoutId: planWorkoutId, name: "推日", targets: [])
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            recentWorkouts: RecentWorkouts(repository: repo),
            plannedProvider: MockPlannedProvider(plan: plan)
        )

        await vm.refresh()

        #expect(vm.recentSessions.map(\.name) == ["推日"])
        #expect(vm.recentSessions.first?.minutes == 72)
        #expect(vm.recentSessions.first?.planWorkoutId == planWorkoutId)
    }

    /// 自由訓練沒有名字，「最近練過」列不出東西，不該混進清單。
    /// 自由訓練也要列進「最近練過」——只做自由訓練的人否則永遠看不到這個區塊，
    /// 也就永遠拿不到「再練一次」這條最短的出路。名稱留 nil，由 View 補「自由訓練」。
    @Test func recentSessionsIncludesFreeTraining() async {
        let repo = MockHomeWorkoutRepo()
        await repo.setFinished([Workout(id: UUID(), day: today, startedAt: Date(), endedAt: Date())])
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            recentWorkouts: RecentWorkouts(repository: repo),
            plannedProvider: MockPlannedProvider(plan: nil)
        )

        await vm.refresh()

        #expect(vm.recentSessions.count == 1)
        #expect(vm.recentSessions.first?.name == nil)
        #expect(vm.recentSessions.first?.planWorkoutId == nil)
    }

    /// 挪課要真的打到 Plan 那一側，而且挪完會 refresh —— 今天不再是休息日。
    @Test func moveNextWorkoutToTodayCallsProviderAndRefreshes() async {
        let repo = MockHomeWorkoutRepo()
        let restDay = RestDayInfo(
            programName: "推拉腿", dayNumber: 3, roundNumber: 7,
            nextWorkoutDate: DayDate(year: 2026, month: 7, day: 27), nextWorkoutName: "腿日"
        )
        let provider = MockPlannedProvider(plan: nil, restDay: restDay)
        let vm = TrainingHomeViewModel(
            startWorkout: StartWorkout(repository: repo),
            resumeWorkout: ResumeWorkout(repository: repo),
            plannedProvider: provider
        )
        await vm.refresh()
        #expect(vm.restDay == restDay)

        await vm.moveNextWorkoutToToday()

        #expect(await provider.moveNextWorkoutCallCount == 1)
        #expect(vm.restDay == nil)
    }
}
