import DesignSystem
import SwiftUI

/// L3 有機體。課表某一天的一列 —— **長期課表投影出來、還沒落地**的訓練。
///
/// 規格：`design-system/organisms/ProjectedWorkoutRow/ProjectedWorkoutRow.spec.md`
///
/// 跟 `PlanWorkoutRow` 的差別不只是顏色：
///   - 圓章是行事曆圖示不是序號 —— 它還沒有序，落地之後才有
///   - **整列不可點**，右側「加入這天」是獨立按鈕。這一列還不是真的排課，
///     不該點哪裡都觸發落地
struct ProjectedWorkoutRow: View {
    let title: Text
    let summary: Text
    let addLabel: Text
    let onAdd: () -> Void

    var body: some View {
        TLListRow(
            title: title,
            subtitle: summary,
            leading: {
                TLBadge(icon: "calendar.badge.clock", fill: TLColor.neutral200, tint: TLColor.neutral600)
            },
            trailing: {
                Button(action: onAdd) {
                    addLabel
                        .font(TLFont.zh(TLFont.rowSub, .semibold))
                        .foregroundStyle(TLColor.accent700)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plan.addThisDay")
            }
        )
    }
}
