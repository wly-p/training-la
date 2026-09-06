import Foundation
import SharedKernel
import Testing
import TrainingDomain

struct WorkoutHistoryExporterTests {
    private let benchPress = UUID()
    private let plank = UUID()

    private func makeWorkout() -> Workout {
        var workout = Workout(
            id: UUID(), day: DayDate(year: 2026, month: 7, day: 20),
            startedAt: Date(timeIntervalSince1970: 1000), endedAt: Date(timeIntervalSince1970: 2000),
            overallFeeling: 4, note: "感覺不錯"
        )
        workout.appendSet(exerciseId: benchPress, measurement: .weightReps(weight: Weight(value: 60, unit: .kg), reps: 8), isWarmup: true)
        workout.appendSet(exerciseId: benchPress, measurement: .weightReps(weight: Weight(value: 60, unit: .kg), reps: 8))
        workout.appendSet(exerciseId: plank, measurement: .duration(seconds: 45))
        return workout
    }

    @Test func recordsFlattenAllSetsWithExerciseNamesLookedUp() {
        let workout = makeWorkout()

        let records = WorkoutHistoryExporter.records(from: [workout], exerciseNames: [benchPress: "臥推"])

        #expect(records.count == 3)
        #expect(records[0].exerciseName == "臥推")
        #expect(records[0].isWarmup == true)
        #expect(records[0].weightValue == 60)
        #expect(records[0].weightUnit == .kg)
        #expect(records[0].reps == 8)
        #expect(records[1].isWarmup == false)
        // plank 沒有在查表裡（動作被刪了）：exerciseName 為 nil，不擋整個匯出
        #expect(records[2].exerciseName == nil)
        #expect(records[2].trackingMode == .duration)
        #expect(records[2].durationSeconds == 45)
        #expect(records[2].weightValue == nil)
    }

    @Test func jsonRoundTripsBackToTheSameRecordCount() throws {
        let workout = makeWorkout()

        let data = try WorkoutHistoryExporter.json(from: [workout], exerciseNames: [:])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([WorkoutExportRecord].self, from: data)

        #expect(decoded.count == 3)
        #expect(Set(decoded.map(\.exerciseId)) == Set(workout.sets.map(\.exerciseId)))
    }

    @Test func csvHasHeaderAndOneLinePerSet() {
        let workout = makeWorkout()

        let csv = String(data: WorkoutHistoryExporter.csv(from: [workout], exerciseNames: [benchPress: "臥推"]), encoding: .utf8)!
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines.count == 4) // header + 3 sets
        #expect(lines[0].hasPrefix("workoutId,day,"))
        #expect(lines[1].contains("臥推"))
    }

    @Test func csvEscapesFieldsContainingCommaOrQuote() {
        var workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 20), note: "備註, 含逗號與\"引號\"")
        workout.appendSet(exerciseId: benchPress, measurement: .reps(10))

        let csv = String(data: WorkoutHistoryExporter.csv(from: [workout], exerciseNames: [:]), encoding: .utf8)!

        #expect(csv.contains("\"備註, 含逗號與\"\"引號\"\"\""))
    }

    @Test func emptyWorkoutListProducesHeaderOnlyCsv() {
        let csv = String(data: WorkoutHistoryExporter.csv(from: [], exerciseNames: [:]), encoding: .utf8)!
        #expect(csv.split(separator: "\n").count == 1)
    }
}
