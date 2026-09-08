import DesignControls
import DesignSystem
import SwiftUI

/// L3 有機體。範本清單的一列。
///
/// 規格：`design-system/organisms/TemplateRow/TemplateRow.spec.md`
///
/// 左滑露出「複製」，長按出刪除選單 —— 兩個入口對應不同頻率的操作。
struct TemplateRow: View {
    let name: String
    /// 副標＝組成摘要（這份範本含哪些動作）。階層關係唯一的傳達管道。
    let summary: Text
    /// 圓章裡的數字＝含幾個動作。
    let blockCount: Int
    let duplicateLabel: Text
    let deleteLabel: Text
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onTap: () -> Void

    var body: some View {
        TLSwipeToRevealRow(
            actionLabel: duplicateLabel,
            actionSystemImage: "doc.on.doc",
            onAction: onDuplicate
        ) {
            TLListRow(
                title: Text(verbatim: name),
                subtitle: summary,
                showChevron: true,
                onTap: onTap,
                // 數字圓章＝含幾個動作（neutral 底，設計稿 5b）
                leading: { TLBadge(count: blockCount, fill: TLColor.neutral300, tint: TLColor.neutral800) }
            )
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label { deleteLabel } icon: { Image(systemName: "trash") }
                }
            }
        }
    }
}
