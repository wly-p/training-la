import SwiftUI

/// 換行流式排列（chip 群用）：一列排不下就換行。左齊。
public struct FlowLayout: Layout {
    private let spacing: CGFloat
    private let lineSpacing: CGFloat

    public init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxLineWidth = max(maxLineWidth, x - spacing)
        }
        return CGSize(width: min(maxLineWidth, maxWidth), height: y + lineHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// 可選取的 capsule chip（單/多選群共用）。`tint` 決定選中色（肌群 `sage`、器材 `accent`）。
///  - 已選：`tint.opacity` 淺底＋深字。未選：1px `text@16%` 線框＋`neutral-700` 字。
/// 標籤吃 `String`（多為 enum 資料 verbatim）。
public struct SelectableChip: View {
    private let label: String
    private let isSelected: Bool
    private let selectedFill: Color
    private let selectedText: Color
    private let onTap: () -> Void

    public init(
        _ label: String,
        isSelected: Bool,
        selectedFill: Color,
        selectedText: Color,
        onTap: @escaping () -> Void
    ) {
        self.label = label
        self.isSelected = isSelected
        self.selectedFill = selectedFill
        self.selectedText = selectedText
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            Text(verbatim: label)
                .font(TLFont.zh(TLFont.rowSub, .semibold))
                .foregroundStyle(isSelected ? selectedText : TLColor.neutral700)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .background {
                    if isSelected {
                        Capsule().fill(selectedFill)
                    } else {
                        Capsule().strokeBorder(TLColor.text.opacity(0.16), lineWidth: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
