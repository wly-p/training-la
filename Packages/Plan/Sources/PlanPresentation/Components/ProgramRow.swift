import DesignSystem
import SwiftUI

/// L3 有機體。長期課表清單的一列。
///
/// 規格：`design-system/organisms/ProgramRow/ProgramRow.spec.md`
///
/// 兩種形態的差別比 `RotationRow` 大 —— 啟用態是**一張卡**不是一列：
///   - **啟用**：卡片（accent 描邊）＋ 上半可 drill-in ＋ 下半進度（天數／今天／進度條）
///   - **未啟用**：一般列，左側可 drill-in、右側 inline「啟用」，兩個獨立點擊區
///
/// 上半用 `TLRowContent` 而不是 `TLListRow`：卡片自己有 padding、只有上半可點，
/// 列的外框（內距、最小高度、整列 Button）全都不適用。
struct ProgramRow: View {
    struct Progress {
        let day: Int
        let totalDays: Int
        let todayWorkoutName: String?
    }

    let id: UUID
    let name: String
    let summary: Text
    /// nil ＝ 未啟用形態。
    let progress: Progress?
    /// 未啟用態右側的「啟用」按鈕；啟用態不用。
    let activateButton: AnyView?
    /// 「N / M 天」的單位字與「今天：」的前綴，由呼叫端給（它才對得到 String Catalog）。
    let dayUnit: Text
    let todayLabel: Text
    /// 長按選單。兩種形態都有。
    let menu: AnyView

    private var badge: some View {
        TLBadge(
            icon: "chart.bar",
            fill: progress != nil ? TLColor.accent : TLColor.neutral300,
            tint: progress != nil ? TLColor.bg : TLColor.neutral600
        )
    }

    private var rowContent: some View {
        TLRowContent(
            title: Text(verbatim: name),
            subtitle: summary,
            showChevron: progress != nil,
            leading: { badge }
        )
        .contentShape(Rectangle())
    }

    var body: some View {
        if let progress {
            activeCard(progress)
        } else {
            inactiveRow.contextMenu { menu }
        }
    }

    private func activeCard(_ progress: Progress) -> some View {
        VStack(spacing: TLSpace.gapM) {
            // 上半：點進詳情頁（8a）
            NavigationLink(value: id) { rowContent }
                .buttonStyle(.plain)

            // 下半：天數＋今天＋進度條
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: TLSpace.numberUnitGap) {
                    Text(verbatim: "\(progress.day)")
                        .font(TLFont.display(TLFont.cardNumber))
                        .foregroundStyle(TLColor.text)
                    (Text(verbatim: "/ \(progress.totalDays) ") + dayUnit)
                        .font(TLFont.zh(TLFont.rowSub))
                        .foregroundStyle(TLColor.neutral500)
                }
                Spacer()
                (todayLabel + Text(verbatim: "：\(progress.todayWorkoutName ?? "—")"))
                    .font(TLFont.zh(TLFont.rowSub, .semibold))
                    .foregroundStyle(TLColor.neutral700)
            }
            // 軌道用預設的 surfaceTrack——這張卡是 neutral-100 的淺底。
            // （深底的那一張在 ProgramDetailView，它才需要傳更淺的軌道。）
            TLProgressBar(ratio: Double(progress.day) / Double(max(1, progress.totalDays)))
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous)
                .strokeBorder(TLColor.accent300, lineWidth: TLSize.hairlineThick)
        }
    }

    private var inactiveRow: some View {
        // 左側可點進詳情頁（8a，可再進編輯）、右側 inline「啟用」——兩個獨立點擊區。
        HStack(spacing: TLSpace.gapM) {
            NavigationLink(value: id) { rowContent }
                .buttonStyle(.plain)
            if let activateButton { activateButton }
        }
        // 未啟用列自己補外框——它不是 TLListRow（右側按鈕要獨立可點），
        // 所以列的內距與最小高度由這裡給。
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: TLSize.rowWithSub)
    }
}
