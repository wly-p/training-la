import DesignSystem
import SwiftUI

/// L3 有機體。歷史清單（依日期）的一列。
///
/// 規格：`design-system/organisms/WorkoutHistoryRow/WorkoutHistoryRow.spec.md`
///
/// 左件是**日期柱**：日數 ＋ 星期縮寫兩行堆疊、固定寬。固定寬是為了讓整個月的
/// 日期左緣對齊——寬度跟著內容走的話，10 號與 9 號那兩列就會差一個字寬。
struct WorkoutHistoryRow: View {
    let day: String
    let weekday: String
    let title: Text
    let summary: Text

    var body: some View {
        TLListRow(
            title: title,
            subtitle: summary,
            showChevron: true,
            leading: { dateColumn }
        )
    }

    private var dateColumn: some View {
        VStack(spacing: TLSpace.dateStackGap) {
            Text(verbatim: day)
                .font(TLFont.display(19))
                .foregroundStyle(TLColor.text)
            Text(verbatim: weekday)
                .font(TLFont.zh(9.5, .medium))
                .foregroundStyle(TLColor.neutral500)
        }
        .frame(width: TLSize.dateColumn)
    }
}
