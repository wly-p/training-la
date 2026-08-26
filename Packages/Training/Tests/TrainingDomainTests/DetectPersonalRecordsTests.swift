import Foundation
import SharedKernel
import Testing
import TrainingDomain

private let exerciseId = UUID()

private func doneSet(_ id: UUID = UUID(), weight: Double, reps: Int, index: Int = 0, setIndex: Int = 0) -> WorkoutSet {
    WorkoutSet(id: id, exerciseId: exerciseId, exerciseIndex: index, setIndex: setIndex,
              measurement: .weightReps(weight: Weight(value: weight, unit: .kg), reps: reps), status: .done)
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
        #expect(prs.first?.measurement.displayReps == 8)
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
        #expect(prs.first?.measurement.displayWeight == Weight(value: 80, unit: .kg))
    }

    /// 規則統一後的行為改變（體檢 P4-4）：歷史有 90kg × 8、這次做 100kg × 5。
    ///
    /// 舊的嚴格規則會判定「沒有 PR」——因為 100kg 這個重量沒出現過（沒有次數可比）、
    /// 5 下這個次數也沒出現過（沒有重量可比），兩個維度都缺基準。
    /// 但使用者的認知很直接：100 比 90 重，這就是新紀錄。
    /// 趨勢圖那側本來就這樣判，於是同一場在摘要沒獎盃、在趨勢圖有——現在兩邊一致。
    @Test func heavierThanAnythingBeforeIsPREvenAtDifferentReps() async throws {
        let repo = MockWorkoutRepository()
        await repo.seed([finishedWorkout(day: DayDate(year: 2026, month: 7, day: 1), sets: [doneSet(weight: 90, reps: 8)])])
        let today = finishedWorkout(day: DayDate(year: 2026, month: 7, day: 24), sets: [doneSet(weight: 100, reps: 5)])
        await repo.seed([today])
        let detect = DetectPersonalRecords(repository: repo)

        let prs = try await detect(today)

        #expect(prs.count == 1)
        #expect(prs.first?.kind == .newWeightAtReps)
        #expect(prs.first?.measurement.displayWeight == Weight(value: 100, unit: .kg))
    }

    /// 反向：比歷來最重的輕，即使次數多很多也不算 PR（不然減重高次數會天天報喜）。
    @Test func lighterThanBestIsNotPREvenWithManyMoreReps() async throws {
        let repo = MockWorkoutRepository()
        await repo.seed([finishedWorkout(day: DayDate(year: 2026, month: 7, day: 1), sets: [doneSet(weight: 100, reps: 5)])])
        let today = finishedWorkout(day: DayDate(year: 2026, month: 7, day: 24), sets: [doneSet(weight: 60, reps: 20)])
        await repo.seed([today])
        let detect = DetectPersonalRecords(repository: repo)

        let prs = try await detect(today)

        #expect(prs.isEmpty)
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

        #expect(prs.first?.measurement.displayWeight == Weight(value: 80, unit: .kg))
        #expect(prs.first?.measurement.displayReps == 5)
    }
}

/// 熱身組不參與 PR 判定（B1）——破紀錄問的是「你真的推了什麼」。
struct PersonalRecordWarmupTests {
    private func warmupSet(weight: Double, reps: Int, setIndex: Int = 0) -> WorkoutSet {
        WorkoutSet(id: UUID(), exerciseId: exerciseId, exerciseIndex: 0, setIndex: setIndex,
                   measurement: .weightReps(weight: Weight(value: weight, unit: .kg), reps: reps), status: .done, isWarmup: true)
    }

    /// 代表組要從正式組裡挑：熱身做很多下不該冒充成「同重量下次數新高」。
    @Test func warmupSetsCannotBecomeTheRepresentativeSet() async throws {
        let repo = MockWorkoutRepository()
        let previous = finishedWorkout(day: DayDate(year: 2026, month: 8, day: 1),
                                       sets: [doneSet(weight: 100, reps: 5)])
        await repo.seed([previous])
        // 今天：熱身 100kg×20（如果被當成代表組就會誤判成 PR），正式組只有 100kg×5 平手
        let today = finishedWorkout(day: DayDate(year: 2026, month: 8, day: 26), sets: [
            warmupSet(weight: 100, reps: 20),
            doneSet(weight: 100, reps: 5, setIndex: 1),
        ])
        await repo.seed([today])

        let prs = try await DetectPersonalRecords(repository: repo)(today)

        #expect(prs.isEmpty)
    }

    /// 歷史裡的熱身組也不算數：不然「上次熱身推了 120」會讓今天真的推 110 變成沒破紀錄。
    @Test func warmupSetsInHistoryDoNotBlockAPersonalRecord() async throws {
        let repo = MockWorkoutRepository()
        let previous = Workout(
            id: UUID(), day: DayDate(year: 2026, month: 8, day: 1),
            startedAt: Date(), endedAt: Date(),
            sets: [warmupSet(weight: 120, reps: 1), doneSet(weight: 100, reps: 5, setIndex: 1)]
        )
        await repo.seed([previous])
        let today = finishedWorkout(day: DayDate(year: 2026, month: 8, day: 26),
                                    sets: [doneSet(weight: 110, reps: 5)])
        await repo.seed([today])

        let prs = try await DetectPersonalRecords(repository: repo)(today)

        #expect(prs.first?.kind == .newWeightAtReps)
        #expect(prs.first?.measurement.displayWeight == Weight(value: 110, unit: .kg))
    }
}
