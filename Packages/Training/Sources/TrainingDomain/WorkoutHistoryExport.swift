import Foundation
import SharedKernel

/// 匯出用：抓全部已完成場次，不設上限（同 History／能力值的用法，跟訓練首頁的「最近幾場」上限無關）。
public struct ExportWorkoutHistory: Sendable {
    private let repository: any WorkoutRepository
    public init(repository: any WorkoutRepository) { self.repository = repository }
    public func callAsFunction() async throws -> [Workout] {
        try await repository.finishedWorkouts(limit: nil)
    }
}

/// 匯出專用的扁平記錄：一組（set）一筆，JSON／CSV 共用同一份資料。
///
/// **不直接對 `SetMeasurement` 掛 `Codable`**：那是 enum with associated values，
/// 直接序列化會讓「不能亂加 case」的保護跟著匯出檔案外流——之後改 enum 的內部表示，
/// 會悄悄改變使用者已經匯出、存在別處的檔案格式。改用這份扁平化欄位，
/// 匯出格式的穩定性跟 domain model 的演進脫鉤。
public struct WorkoutExportRecord: Codable, Sendable, Equatable {
    public let workoutId: UUID
    public let day: String  // DayDate.isoString，"yyyy-MM-dd"
    public let startedAt: Date?
    public let endedAt: Date?
    public let overallFeeling: Int?
    public let note: String?
    public let exerciseId: UUID
    /// 由 App 層 adapter 查表填入；Training 不認識 Spec 的動作名稱。查不到就是 nil。
    public let exerciseName: String?
    public let exerciseIndex: Int
    public let setIndex: Int
    public let trackingMode: TrackingMode
    public let weightValue: Double?
    public let weightUnit: WeightUnit?
    public let reps: Int?
    public let durationSeconds: Int?
    public let distanceMeters: Double?
    public let status: WorkoutSetStatus
    public let isWarmup: Bool

    public init(
        workoutId: UUID,
        day: String,
        startedAt: Date?,
        endedAt: Date?,
        overallFeeling: Int?,
        note: String?,
        exerciseId: UUID,
        exerciseName: String?,
        exerciseIndex: Int,
        setIndex: Int,
        trackingMode: TrackingMode,
        weightValue: Double?,
        weightUnit: WeightUnit?,
        reps: Int?,
        durationSeconds: Int?,
        distanceMeters: Double?,
        status: WorkoutSetStatus,
        isWarmup: Bool
    ) {
        self.workoutId = workoutId
        self.day = day
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.overallFeeling = overallFeeling
        self.note = note
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.trackingMode = trackingMode
        self.weightValue = weightValue
        self.weightUnit = weightUnit
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.status = status
        self.isWarmup = isWarmup
    }
}

/// 把 `[Workout]` 轉成扁平記錄，再產生 JSON／CSV。純函式，不碰任何 IO（寫檔留給 App 層 adapter）。
public enum WorkoutHistoryExporter {
    /// `exerciseNames`：App 層用 Spec 的 `ListExercises` 查好餵進來（同 `PlanProviderAdapter` 的 pattern）；
    /// Training 不 import Spec。查不到（動作被刪了）時該筆 `exerciseName` 為 nil，不擋整個匯出。
    public static func records(from workouts: [Workout], exerciseNames: [UUID: String]) -> [WorkoutExportRecord] {
        workouts.flatMap { workout in
            workout.sets.map { set in
                record(for: set, in: workout, exerciseNames: exerciseNames)
            }
        }
    }

    private static func record(
        for set: WorkoutSet, in workout: Workout, exerciseNames: [UUID: String]
    ) -> WorkoutExportRecord {
        var weightValue: Double?
        var weightUnit: WeightUnit?
        var reps: Int?
        var durationSeconds: Int?
        var distanceMeters: Double?
        switch set.measurement {
        case .weightReps(let weight, let r):
            weightValue = weight.value; weightUnit = weight.unit; reps = r
        case .bodyweightPlus(let added, let r):
            weightValue = added.value; weightUnit = added.unit; reps = r
        case .reps(let r):
            reps = r
        case .duration(let seconds):
            durationSeconds = seconds
        case .distance(let meters):
            distanceMeters = meters
        }
        return WorkoutExportRecord(
            workoutId: workout.id,
            day: workout.day.isoString,
            startedAt: workout.startedAt,
            endedAt: workout.endedAt,
            overallFeeling: workout.overallFeeling,
            note: workout.note,
            exerciseId: set.exerciseId,
            exerciseName: exerciseNames[set.exerciseId],
            exerciseIndex: set.exerciseIndex,
            setIndex: set.setIndex,
            trackingMode: set.measurement.mode,
            weightValue: weightValue,
            weightUnit: weightUnit,
            reps: reps,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            status: set.status,
            isWarmup: set.isWarmup
        )
    }

    public static func json(from workouts: [Workout], exerciseNames: [UUID: String]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(records(from: workouts, exerciseNames: exerciseNames))
    }

    private static let csvHeader = [
        "workoutId", "day", "startedAt", "endedAt", "overallFeeling", "note",
        "exerciseId", "exerciseName", "exerciseIndex", "setIndex", "trackingMode",
        "weightValue", "weightUnit", "reps", "durationSeconds", "distanceMeters",
        "status", "isWarmup",
    ].joined(separator: ",")

    public static func csv(from workouts: [Workout], exerciseNames: [UUID: String]) -> Data {
        let isoFormatter = ISO8601DateFormatter()
        var lines = [csvHeader]
        for record in records(from: workouts, exerciseNames: exerciseNames) {
            let fields: [String] = [
                record.workoutId.uuidString,
                record.day,
                record.startedAt.map(isoFormatter.string) ?? "",
                record.endedAt.map(isoFormatter.string) ?? "",
                record.overallFeeling.map(String.init) ?? "",
                record.note ?? "",
                record.exerciseId.uuidString,
                record.exerciseName ?? "",
                String(record.exerciseIndex),
                String(record.setIndex),
                record.trackingMode.rawValue,
                record.weightValue.map { String($0) } ?? "",
                record.weightUnit?.rawValue ?? "",
                record.reps.map(String.init) ?? "",
                record.durationSeconds.map(String.init) ?? "",
                record.distanceMeters.map { String($0) } ?? "",
                record.status.rawValue,
                String(record.isWarmup),
            ]
            lines.append(fields.map(csvEscaped).joined(separator: ","))
        }
        return Data(utf8BOM) + Data(lines.joined(separator: "\n").utf8)
    }

    /// UTF-8 BOM。CSV 沒有欄位可以宣告編碼，Excel 看到沒有 BOM 的檔就用系統 ANSI 碼頁
    /// （繁中 Windows 是 Big5）去解——動作名稱與備註的中文整排變亂碼，而 CSV 存在的理由
    /// 正是「拿去試算表開」。Numbers／Google Sheets 有沒有 BOM 都讀得對，加了沒有壞處。
    /// JSON 不加：RFC 8259 明講不該有，會讓嚴格的 parser 直接失敗。
    static let utf8BOM: [UInt8] = [0xEF, 0xBB, 0xBF]

    /// 逗號、引號、換行都要用雙引號包起來，內部的雙引號自我轉義（標準 CSV 規則）。
    /// 換行包含 `\r`——備註是自由輸入，貼上的文字可能帶 CRLF，漏掉它會把一筆拆成兩列。
    private static func csvEscaped(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
