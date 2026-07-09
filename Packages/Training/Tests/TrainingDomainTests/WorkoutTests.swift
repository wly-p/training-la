import Foundation
import SharedKernel
import Testing
import TrainingDomain

struct WorkoutAppendSetTests {
    private func makeWorkout() -> Workout {
        Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 9))
    }

    private let kg60 = Weight(value: 60, unit: .kg)

    @Test func firstSetOpensBlockZero() {
        var workout = makeWorkout()
        let benchPress = UUID()

        workout.appendSet(exerciseId: benchPress, weight: kg60, reps: 8)

        #expect(workout.sets.count == 1)
        #expect(workout.sets[0].exerciseIndex == 0)
        #expect(workout.sets[0].setIndex == 0)
    }

    @Test func sameExerciseAppendsToSameBlock() {
        var workout = makeWorkout()
        let benchPress = UUID()

        workout.appendSet(exerciseId: benchPress, weight: kg60, reps: 8)
        workout.appendSet(exerciseId: benchPress, weight: kg60, reps: 6)

        #expect(workout.blocks.count == 1)
        #expect(workout.sets.map(\.setIndex) == [0, 1])
    }

    @Test func newExerciseOpensNextBlock() {
        var workout = makeWorkout()
        let benchPress = UUID()
        let squat = UUID()

        workout.appendSet(exerciseId: benchPress, weight: kg60, reps: 8)
        workout.appendSet(exerciseId: squat, weight: kg60, reps: 5)

        #expect(workout.blocks.count == 2)
        #expect(workout.blocks[1].exerciseId == squat)
        #expect(workout.blocks[1].sets[0].exerciseIndex == 1)
        #expect(workout.blocks[1].sets[0].setIndex == 0)
    }

    @Test func reselectingEarlierExerciseAppendsToItsBlock() {
        var workout = makeWorkout()
        let benchPress = UUID()
        let squat = UUID()

        workout.appendSet(exerciseId: benchPress, weight: kg60, reps: 8)
        workout.appendSet(exerciseId: squat, weight: kg60, reps: 5)
        workout.appendSet(exerciseId: benchPress, weight: kg60, reps: 7)

        // 回頭補臥推：接回原本的 block（exerciseIndex 0, setIndex 1）
        let benchBlock = workout.blocks.first { $0.exerciseId == benchPress }!
        #expect(benchBlock.sets.map(\.setIndex) == [0, 1])
        #expect(workout.blocks.count == 2)
    }

    @Test func blocksAreSortedByIndex() {
        var workout = makeWorkout()
        for _ in 0..<3 {
            workout.appendSet(exerciseId: UUID(), weight: kg60, reps: 8)
        }

        #expect(workout.blocks.map(\.exerciseIndex) == [0, 1, 2])
    }
}

struct WorkoutUseCaseTests {
    private let kg60 = Weight(value: 60, unit: .kg)

    @Test func startWorkoutPersistsImmediately() async throws {
        let repo = MockWorkoutRepository()
        let fixedID = UUID()
        let fixedDate = Date(timeIntervalSince1970: 5_000)
        let today = DayDate(year: 2026, month: 7, day: 9)
        let start = StartWorkout(
            repository: repo, makeID: { fixedID }, now: { fixedDate }, today: { today })

        let workout = try await start()

        #expect(workout.id == fixedID)
        #expect(workout.day == today)
        #expect(workout.startedAt == fixedDate)
        #expect(workout.isFinished == false)
        #expect(try await repo.get(id: fixedID) == workout)
    }

    @Test func resumeFindsUnfinishedWorkout() async throws {
        let repo = MockWorkoutRepository()
        var finished = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 8), startedAt: Date())
        finished.endedAt = Date()
        let active = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 9), startedAt: Date())
        await repo.seed([finished, active])

        let resumed = try await ResumeWorkout(repository: repo)()

        #expect(resumed?.id == active.id)
    }

    @Test func finishSetsFieldsAndPersists() async throws {
        let repo = MockWorkoutRepository()
        var workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 9), startedAt: Date())
        workout.appendSet(exerciseId: UUID(), weight: kg60, reps: 8)
        await repo.seed([workout])
        let endTime = Date(timeIntervalSince1970: 9_000)
        let finish = FinishWorkout(repository: repo, now: { endTime })

        let finished = try await finish(workout, overallFeeling: 4, note: "狀態不錯")

        #expect(finished.endedAt == endTime)
        #expect(finished.overallFeeling == 4)
        #expect(finished.note == "狀態不錯")
        #expect(try await repo.get(id: workout.id)?.isFinished == true)
    }

    @Test func startFromBlueprintRecordsPlanSource() async throws {
        let repo = MockWorkoutRepository()
        let planWorkoutId = UUID()
        let blueprint = PlannedWorkoutBlueprint(planWorkoutId: planWorkoutId, name: "推日", targets: [])
        let start = StartWorkout(repository: repo)

        let workout = try await start(blueprint: blueprint)

        #expect(workout.planWorkoutId == planWorkoutId)
    }

    @Test func finishPlanLinkedWorkoutMarksPlanDone() async throws {
        let repo = MockWorkoutRepository()
        let recorder = SpyPlanProgress()
        let planWorkoutId = UUID()
        var workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 9),
                              planWorkoutId: planWorkoutId, startedAt: Date())
        workout.appendSet(exerciseId: UUID(), weight: kg60, reps: 8)
        await repo.seed([workout])
        let finish = FinishWorkout(repository: repo, planProgress: recorder)

        try await finish(workout, overallFeeling: nil, note: nil)

        #expect(await recorder.markedDone == [planWorkoutId])
    }

    @Test func finishFreeWorkoutDoesNotTouchPlan() async throws {
        let repo = MockWorkoutRepository()
        let recorder = SpyPlanProgress()
        let workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 9), startedAt: Date())
        await repo.seed([workout])
        let finish = FinishWorkout(repository: repo, planProgress: recorder)

        try await finish(workout, overallFeeling: nil, note: nil)

        #expect(await recorder.markedDone.isEmpty)
    }

    @Test func finishRejectsFeelingOutOfRange() async throws {
        let repo = MockWorkoutRepository()
        let workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 9))
        let finish = FinishWorkout(repository: repo)

        await #expect(throws: FinishWorkoutError.feelingOutOfRange) {
            try await finish(workout, overallFeeling: 6, note: nil)
        }
    }

    @Test func discardDeletesWorkout() async throws {
        let repo = MockWorkoutRepository()
        let workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 9))
        await repo.seed([workout])

        try await DiscardWorkout(repository: repo)(id: workout.id)

        #expect(try await repo.get(id: workout.id) == nil)
    }
}

struct DayDateTests {
    @Test func isoStringRoundTrips() {
        let day = DayDate(year: 2026, month: 7, day: 9)
        #expect(day.isoString == "2026-07-09")
        #expect(DayDate(isoString: "2026-07-09") == day)
    }

    @Test func comparesChronologically() {
        #expect(DayDate(year: 2026, month: 6, day: 30) < DayDate(year: 2026, month: 7, day: 1))
        #expect(DayDate(year: 2025, month: 12, day: 31) < DayDate(year: 2026, month: 1, day: 1))
    }
}
