import DesignControls
import DesignSystem
import SwiftUI

/// L3 有機體。循環清單的一列。
///
/// 規格：`design-system/organisms/RotationRow/RotationRow.spec.md`
///
/// 兩種形態，差別不只是顏色：
///   - **啟用**：可 drill-in（有 chevron）、右側顯示進度膠囊、左滑可停用
///   - **未啟用**：不 drill-in（設計稿無 chevron，低頻編輯先啟用再進）、右側 inline「啟用」
struct RotationRow: View {
    enum Mode { case active, inactive }

    let mode: Mode
    /// drill-in 的目的地。啟用態才用得到——未啟用列刻意不 drill-in。
    let id: UUID
    let name: String
    let subtitle: Text
    /// 右側內容：啟用態是進度膠囊、未啟用態是「啟用」按鈕。由呼叫端給——
    /// 它才知道要顯示什麼文案與行為。
    let trailing: AnyView
    let deactivateLabel: Text
    let onDeactivate: () -> Void
    let menu: AnyView

    private var badge: some View {
        TLBadge(
            icon: "arrow.triangle.2.circlepath",
            fill: mode == .active ? TLColor.accent : TLColor.neutral300,
            tint: mode == .active ? TLColor.bg : TLColor.neutral600
        )
    }

    private var row: some View {
        TLListRow(
            title: Text(verbatim: name),
            subtitle: subtitle,
            showChevron: mode == .active,
            leading: { badge },
            trailing: { trailing }
        )
    }

    var body: some View {
        switch mode {
        case .active:
            // 左滑露出「停用」（8b，neutral-400、非紅）→ accent 確認；
            // drill-in 用 value-based NavigationLink。
            TLSwipeToRevealRow(
                actionLabel: deactivateLabel,
                actionSystemImage: "pause",
                onAction: onDeactivate
            ) {
                NavigationLink(value: id) { row }
                    .buttonStyle(.plain)
            }
            .contextMenu { menu }
        case .inactive:
            row.contextMenu { menu }
        }
    }
}
