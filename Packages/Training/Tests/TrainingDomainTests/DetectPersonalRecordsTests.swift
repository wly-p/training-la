import Foundation
import SharedKernel
import Testing
import TrainingDomain

private let exerciseId = UUID()

private func doneSet(_ id: UUID = UUID(), weight: Double, reps: Int, index: Int = 0, setIndex: Int = 0) -> WorkoutSet {
    WorkoutSet(id: id, exerciseId: exerciseId, exerciseIndex: index, setIndex: setIndex,
              weight: Weight(value: weight, unit: .kg), reps: reps, status: .done)
}

private func finishedWorkout(day: DayDate, sets: [WorkoutSet]) -> Workout {
    Workout(id: UUID(), day: day, startedAt: Date(), endedAt: Date(), sets: sets)
}

struct DetectPersonalRecordsTests {
    @Test func detectsNewRepsAtSameWeightAsPR() async throws {
        let repo = MockWorkoutRepository()
        await repo.seed([finishedWorkout(day: DayDate(year: 2026, month: 7, day: 1), sets: [doneSet(weight: 80, reps: 6)])])
        let detect = DetectPersonalRecords(repository: repo)
        let today = finishedWorkout(day: DayDate(year: 2026, month: 7, day: 24), sets: [doneSet(weight: 80, reps: 8)])
        await repo.seed([today])   // 這場也已經存進去（跟實際流程一致：finish 先存，才偵測 PR）

        let prs = try await detect(today)

        #expect(prs.count == 1)
        #expect(prs.first?.kind == .newRepsAtWeight)
        #expect(prs.first?.reps == 8)
    }

    @Test func detectsNewWeightAtSameRepsAsPR() async throws {
        let repo = MockWorkoutRepository()
        await repo.seed([finishedWorkout(day: DayDate(year: 2026, month: 7, day: 1), sets: [doneSet(weight: 70, reps: 8)])])
        let today = finishedWorkout(day: DayDate(year: 2026, month: 7, day: 24), sets: [doneSet(weight: 80, reps: 8)])
        await repo.seed([today])
        let detect = DetectPersonalRecords(repository: repo)

        let prs = try await detect(today)

        #expect(prs.count == 1)
        #expect(prs.first?.kind == .newWeightAtReps)
        #expect(prs.first?.weight == Weight(value: 80, unit: .kg))
    }

    @Test func noRecordWhenNeitherDimensionImproves() async throws {
        let repo = MockWorkoutRepository()
        await repo.seed([finishedWorkout(day: DayDate(year: 2026, month: 7, day: 1), sets: [doneSet(weight: 80, reps: 8)])])
        let today = finishedWorkout(day: DayDate(year: 2026, month: 7, day: 24), sets: [doneSet(weight: 80, reps: 8)])
        await repo.seed([today])
        let detect = DetectPersonalRecords(repository: repo)

        let prs = try await detect(today)

        #expect(prs.isEmpty)
    }

    @Test func noHistoryStillCountsAsPR() async throws {
        let repo = MockWorkoutRepository()
        let today = finishedWorkout(day: DayDate(year: 2026, month: 7, day: 24), sets: [doneSet(weight: 60, reps: 8)])
        await repo.seed([today])
        let detect = DetectPersonalRecords(repository: repo)

        let prs = try await detect(today)

        #expect(prs.count == 1)   // 第一次練這個動作，任何一組都算創新高
    }

    @Test func skippedSetsAreNotCandidatesForPR() async throws {
        let repo = MockWorkoutRepository()
        var skipped = doneSet(weight: 999, reps: 99)
        skipped.status = .skipped
        let today = finishedWorkout(day: DayDate(year: 2026, month: 7, day: 24), sets: [skipped])
        await repo.seed([today])
        let detect = DetectPersonalRecords(repository: repo)

        let prs = try await detect(today)

        #expect(prs.isEmpty)   // 跳過的組不是「真的做了」，不該被拿來宣告 PR
    }

    @Test func picksHeaviestSetAsRepresentativeWhenMultipleSets() async throws {
        let repo = MockWorkoutRepository()
        let today = finishedWorkout(day: DayDate(year: 2026, month: 7, day: 24), sets: [
            doneSet(weight: 60, reps: 10, setIndex: 0),
            doneSet(weight: 80, reps: 5, setIndex: 1),   // 最重的這組才是代表組
        ])
        await repo.seed([today])
        let detect = DetectPersonalRecords(repository: repo)

        let prs = try await detect(today)

        #expect(prs.first?.weight == Weight(value: 80, unit: .kg))
        #expect(prs.first?.reps == 5)
    }
}
