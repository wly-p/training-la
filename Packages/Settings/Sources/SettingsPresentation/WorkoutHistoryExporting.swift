import Foundation

/// 匯出訓練歷史的介面。實作在 App（Composition Root）——那裡才認得 Training 的
/// repository 與 Spec 的動作名稱查表。抽成 protocol 讓 ViewModel 可注入 mock 測試。
public protocol WorkoutHistoryExporting: Sendable {
    /// 產生 JSON 檔並寫進暫存目錄，回傳可分享的 URL。
    func exportJSON() async throws -> URL
    /// 產生 CSV 檔並寫進暫存目錄，回傳可分享的 URL。
    func exportCSV() async throws -> URL
}

/// 測試 / 預覽用的空實作：一律失敗（沒有歷史可匯出的情境用不到，測試請自行注入 stub）。
public struct NoopWorkoutHistoryExporting: WorkoutHistoryExporting {
    public struct NotAvailable: Error {}
    public init() {}
    public func exportJSON() async throws -> URL { throw NotAvailable() }
    public func exportCSV() async throws -> URL { throw NotAvailable() }
}
