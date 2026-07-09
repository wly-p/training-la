/// 肌群分類。rawValue 為儲存與 API 契約共用的英文 token。
public enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case core
    case functional
    case other

    /// 中文顯示名（純字串、跨 domain 的 UI 都用得到，故放 SharedKernel）。
    public var displayName: String {
        switch self {
        case .chest: "胸"
        case .back: "背"
        case .legs: "腿"
        case .shoulders: "肩"
        case .arms: "手臂"
        case .core: "核心"
        case .functional: "功能性訓練"
        case .other: "其他"
        }
    }
}
