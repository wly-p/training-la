import SwiftUI

/// 模板 6：肌群標籤。capsule、padding 5×12、11.5pt weight 600。
///  - 已選：`sage-200` 底 + `sage-800` 字
///  - 未選：1px `#201E1D`@16% 線框 + `neutral-700` 字
///
/// 八個肌群共用一個綠，不要八種顏色。
public struct MuscleTag: View {
    private let label: String
    private let isSelected: Bool
    private let onTap: (() -> Void)?

    public init(_ label: String, isSelected: Bool = false, onTap: (() -> Void)? = nil) {
        self.label = label
        self.isSelected = isSelected
        self.onTap = onTap
    }

    private var chip: some View {
        Text(label)
            .font(TLFont.zh(TLFont.rowSub, .semibold))
            .foregroundStyle(isSelected ? TLColor.sage800 : TLColor.neutral700)
            .padding(.vertical, 5)
            .padding(.horizontal, 12)
            .background {
                if isSelected {
                    Capsule().fill(TLColor.sage200)
                } else {
                    Capsule().strokeBorder(TLColor.text.opacity(0.16), lineWidth: 1)
                }
            }
            .contentShape(Capsule())
    }

    public var body: some View {
        if let onTap {
            Button(action: onTap) { chip }.buttonStyle(.plain)
        } else {
            chip
        }
    }
}
