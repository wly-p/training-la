/// 器材分類。rawValue 為儲存與 API 契約共用的英文 token（對齊 client v0.5.0 的 Equipment）。
public enum Equipment: String, CaseIterable, Codable, Sendable {
    case barbell
    case dumbbell
    case kettlebell
    case hexBar = "hex_bar"
    case machine
    case cable
    case band
    case bodyweight
    case other

    /// 中文顯示名（純字串、跨 domain 的 UI 都用得到，故放 SharedKernel）。
    public var displayName: String {
        switch self {
        case .barbell: "槓鈴"
        case .dumbbell: "啞鈴"
        case .kettlebell: "壺鈴"
        case .hexBar: "六角槓"
        case .machine: "機械"
        case .cable: "纜繩"
        case .band: "彈力帶"
        case .bodyweight: "自體重量"
        case .other: "其他"
        }
    }
}
