import Foundation

/// 清除全部使用者資料的介面。實作在 App（Composition Root）——那裡才認得各 domain 的 SwiftData 儲存。
/// 只清資料（動作庫、課表、訓練紀錄），**不動 UserDefaults 顯示偏好**（主題、App 圖示保留）。
/// 抽成 protocol 讓 ViewModel 可注入 mock 測試（免模擬器、免真實資料庫）。
public protocol DataErasing: Sendable {
    /// 清空所有本機資料。完成後 App 應回到全新初始狀態。
    func eraseAllData() async throws
}

/// 測試 / 預覽用的空實作。
public struct NoopDataEraser: DataErasing {
    public init() {}
    public func eraseAllData() async throws {}
}
