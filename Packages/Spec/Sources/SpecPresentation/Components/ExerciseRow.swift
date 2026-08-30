import DesignSystem
import SpecDomain
import SwiftUI

/// L3 有機體。動作清單的一列。
///
/// 規格：`design-system/organisms/ExerciseRow/ExerciseRow.spec.md`
///
/// 內建動作（`OfficialExerciseCatalog`）唯讀：不進編輯表單、沒有刪除選單，
/// 也不顯示 chevron —— 留著箭頭卻點不動比沒有箭頭更難懂。
struct ExerciseRow: View {
    let name: String
    let isOfficial: Bool
    /// 尾欄標籤：依分組顯示肌群或器材。呼叫端決定顯示哪一個（它才知道目前的分組）。
    let tailLabel: String
    /// 尾欄的 UITest 定位鍵（`muscleTag` / `equipmentTag`），讓測試分得出這一列標的是什麼。
    let tailIdentifier: String
    let deleteLabel: Text
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        TLListRow(
            title: Text(verbatim: name),
            showChevron: !isOfficial,
            onTap: isOfficial ? nil : onEdit,
            trailing: {
                // 18b：唯一的彩色元素，固定尾欄靠右。
                // minWidth 讓長標往左長、右緣仍對齊；寫死 width 會把長標壓成兩行。
                TLEquipmentTag(tailLabel, identifier: tailIdentifier)
                    .frame(minWidth: TLSize.rowTailColumn, alignment: .trailing)
            }
        )
        // 內建動作的名稱會跟著 app 語言換，測試沒辦法用名字找到它——改認這個 id。
        // 使用者自建的動作名是測試自己輸入的資料，照舊用文字定位。
        .accessibilityIdentifier(isOfficial ? "exerciseList.officialRow" : "exerciseList.row")
        // 整個 modifier 拿掉、而不是留一個空的 menu：空 menu 長按仍會有抬起動畫卻沒有選項。
        .contextMenu(isOfficial ? nil : ContextMenu {
            Button(role: .destructive, action: onDelete) {
                Label { deleteLabel } icon: { Image(systemName: "trash") }
            }
            .accessibilityIdentifier("exerciseList.delete")
        })
    }
}
