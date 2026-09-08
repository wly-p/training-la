import Foundation
import SharedKernel

/// 動作庫的儲存介面。Data 層提供實作；上層一律只依賴此 protocol。
public protocol ExerciseRepository: Sendable {
    /// 列出動作，依名稱排序；`muscleGroup` 非 nil 時過濾。
    func list(muscleGroup: MuscleGroup?) async throws -> [Exercise]
    func get(id: UUID) async throws -> Exercise?
    func create(_ exercise: Exercise) async throws
    func update(_ exercise: Exercise) async throws
    func delete(id: UUID) async throws
}

public enum ExerciseRepositoryError: Error, Equatable, Sendable {
    case notFound(id: UUID)
    /// 動作被課表 / 訓練紀錄引用，無法刪除（對齊 API 契約的 `in_use`）。
    case inUse(id: UUID)
    /// 內建動作（``OfficialExerciseCatalog``）唯讀，不可編輯也不可刪除。
    case readOnly(id: UUID)
}

/// 「這個動作有沒有被引用」的查詢 port。
/// 本地由 App 接到 Training / Plan 的資料落實；未來走 API 時改由伺服器的 409 落實，此 port 不再被 wire。
public protocol ExerciseUsageChecking: Sendable {
    func isUsed(exerciseId: UUID) async throws -> Bool
}

/// 引用某動作的一筆 spec（範本／循環／長期），供編輯頁「被使用於」護欄顯示（設計稿 9a）。
public struct ExerciseUsageRef: Identifiable, Equatable, Sendable {
    public enum Kind: Sendable { case template, rotation, program }
    public let id: UUID
    public let name: String
    public let kind: Kind
    public init(id: UUID, name: String, kind: Kind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

/// 「這個動作被哪些 spec 用到」的名稱清單查詢 port（刪除前護欄）。
/// 同 `ExerciseUsageChecking`：本地由 App 接到 Plan 的資料落實，未來走 API 換伺服器實作。
public protocol ExerciseUsageListing: Sendable {
    func usages(exerciseId: UUID) async throws -> [ExerciseUsageRef]
}

/// 「每個動作練過幾次」的統計 port（動作庫「常用」分組用）。
///
/// 計次單位是**場次**不是組數：一場練 5 組臥推只算 1 次。用組數的話，
/// 高組數動作會永遠壓過真正常做的動作——「常用」問的是「你多常做它」，不是「你做了幾組」。
///
/// 資料在 Training 的訓練紀錄裡，而 Spec 不依賴 Training，所以走 port 由 App 接線
/// （同 `ExerciseUsageListing` 的作法）。
public protocol ExerciseUsageCounting: Sendable {
    /// 回傳 exerciseId → 練過的場次數。沒練過的動作不會出現在字典裡。
    func usageCounts() async throws -> [UUID: Int]
}
