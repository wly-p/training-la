/// 內容來源：區分「自行建立」與「線上公開／官方」。動作（Exercise）與課表範本（Template）共用。
/// rawValue 對齊未來 API 契約；本地資料一律 `.user`，接 API 後公開內容為 `.official`。
public enum ContentSource: String, CaseIterable, Codable, Sendable {
    case user      // 自行建立
    case official  // 線上公開／官方
    // 未來擴充：community

    /// 中文顯示名（來源標籤／filter UI 用）。
    public var displayName: String {
        switch self {
        case .user: "自建"
        case .official: "官方"
        }
    }
}
