/// 肌群分類。rawValue 為儲存與 API 契約共用的英文 token；中文顯示由 Presentation 層對應。
public enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case core
    case functional
    case other
}
