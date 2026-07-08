import SharedKernel

extension MuscleGroup {
    /// 中文顯示名。儲存與 API 一律用英文 token，只有這裡負責翻成給人看的字。
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
