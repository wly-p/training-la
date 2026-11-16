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

    /// 把 CSV 解成文字，**自己把開頭的 BOM 剝掉**。
    ///
    /// 不能靠 `String(data:encoding:)`：它吃不吃 BOM 隨 Foundation 版本而異——
    /// macOS 26 會吃掉，CI 的 macOS 15 會留成一個 U+FEFF。斷言寫成任一種都會在另一邊紅。
    private func csvText(from workouts: [Workout], exerciseNames: [UUID: String]) -> String {
        let data = WorkoutHistoryExporter.csv(from: workouts, exerciseNames: exerciseNames)
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        let body = Array(data.prefix(bom.count)) == bom ? data.dropFirst(bom.count) : data[...]
        return String(decoding: body, as: UTF8.self)
    }

    @Test func csvHasHeaderAndOneLinePerSet() {
        let workout = makeWorkout()

        let csv = csvText(from: [workout], exerciseNames: [benchPress: "臥推"])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)

        #expect(lines.count == 4) // header + 3 sets
        // BOM 已經由 `csvText` 剝掉，這裡看到的直接是表頭；BOM 本身由 `csvStartsWithUTF8BOM` 在 byte 層驗。
        #expect(lines[0].hasPrefix("workoutId,day,"))
        #expect(lines[1].contains("臥推"))
    }

    /// Excel 沒看到 BOM 就用系統碼頁（繁中 Windows＝Big5）解，中文動作名會變亂碼。
    @Test func csvStartsWithUTF8BOM() {
        let data = WorkoutHistoryExporter.csv(from: [makeWorkout()], exerciseNames: [benchPress: "臥推"])
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
    }

    /// JSON 不能有 BOM（RFC 8259）。
    @Test func jsonHasNoBOM() throws {
        let data = try WorkoutHistoryExporter.json(from: [makeWorkout()], exerciseNames: [:])
        #expect(Array(data.prefix(3)) != [0xEF, 0xBB, 0xBF])
        #expect(data.first == UInt8(ascii: "["))
    }

    /// 備註貼進來的文字可能帶 CRLF；沒包起來的話一筆會被拆成兩列。
    @Test func csvEscapesCarriageReturn() {
        var workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 20), note: "第一行\r\n第二行")
        workout.appendSet(exerciseId: benchPress, measurement: .reps(10))

        let csv = csvText(from: [workout], exerciseNames: [:])

        #expect(csv.contains("\"第一行\r\n第二行\""))
    }

    @Test func csvEscapesFieldsContainingCommaOrQuote() {
        var workout = Workout(id: UUID(), day: DayDate(year: 2026, month: 7, day: 20), note: "備註, 含逗號與\"引號\"")
        workout.appendSet(exerciseId: benchPress, measurement: .reps(10))

        let csv = csvText(from: [workout], exerciseNames: [:])

        #expect(csv.contains("\"備註, 含逗號與\"\"引號\"\"\""))
    }

    @Test func emptyWorkoutListProducesHeaderOnlyCsv() {
        let csv = csvText(from: [], exerciseNames: [:])
        #expect(csv.split(separator: "\n").count == 1)
    }
}
