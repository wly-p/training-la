import DesignSystem
import SwiftUI

/// L3 有機體。課表某一天的一列 —— **已經排定**的訓練。
///
/// 規格：`design-system/organisms/PlanWorkoutRow/PlanWorkoutRow.spec.md`
///
/// 圓章同時是序號與狀態：未完成顯示第幾項（neutral），完成後換成勾（accent）。
/// 兩種狀態共用同一顆圓章是刻意的 —— 那一格回答的永遠是「這一項的進度」。
struct PlanWorkoutRow: View {
    let title: Text
    let summary: Text
    let orderIndex: Int
    let isDone: Bool
    let onTap: () -> Void

    var body: some View {
        TLListRow(
            title: title,
            subtitle: summary,
            showChevron: true,
            onTap: onTap,
            leading: { badge }
        )
    }

    private var badge: some View {
        TLBadge(fill: isDone ? TLColor.accent : TLColor.neutral300) {
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: TLIcon.inline, weight: .bold))
                    .foregroundStyle(TLColor.bg)
            } else {
                Text(verbatim: "\(orderIndex + 1)")
                    .font(TLFont.display(15))
                    .foregroundStyle(TLColor.neutral700)
            }
        }
    }
}
