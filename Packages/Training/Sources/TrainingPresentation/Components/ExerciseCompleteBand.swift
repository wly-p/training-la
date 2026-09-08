import DesignSystem
import SwiftUI

/// L3 有機體。動作／課表做完時的完成區（16b／16e）。
///
/// 規格：`design-system/organisms/ExerciseCompleteBand/ExerciseCompleteBand.spec.md`
///
/// **不是彈窗**：就地把輸入色帶換成綠色完成區 —— 同一位置、同一形狀，只換底色與內容。
/// 組表與最後一組的 ↩ 完全不動，誤按的人什麼都不用做就能復原。
///
/// 舊實作是蓋住全螢幕的彈窗：它出現在狀態已經前進之後，所以不是防誤按而是事後追問，
/// 還跟組表上既有的 ↩ 重疊。
struct ExerciseCompleteBand: View {
    /// 課表整份做完（16e）還是只有這個動作做完（16b）。兩者的文案、按鈕數、主鈕行為都不同。
    let isPlanFullyDone: Bool
    let title: Text
    let message: String
    let primaryTitle: String
    let oneMoreSetLabel: Text
    let addExtraLabel: Text
    let onOneMoreSet: () -> Void
    let onAddExtra: () -> Void
    let onPrimary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TLSpace.sectionHeaderGap) {
            Label {
                title
                    .font(TLFont.zh(TLFont.rowTitle, .semibold))
                    .foregroundStyle(TLColor.sage900)
                    // 動作做完／課表做完是兩句不同的文案，測試只認「完成區的標題在不在」。
                    .accessibilityIdentifier("activeWorkout.completeBandTitle")
            } icon: {
                Image(systemName: isPlanFullyDone ? "flag" : "checkmark")
                    .font(.system(size: TLIcon.inline, weight: .bold))
                    .foregroundStyle(TLColor.sage900)
            }
            Text(verbatim: message)
                .font(TLFont.zh(TLFont.rowSub, .regular))
                .foregroundStyle(TLColor.sage800.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            actions
                .padding(.top, TLSpace.valueUnitGap)
        }
        .padding(.vertical, TLSpace.rowInset)
        .padding(.leading, TLSpace.page)
        .padding(.trailing, TLSpace.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TLColor.sage200)
        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: TLRadius.band,
                                          topTrailingRadius: TLRadius.band, style: .continuous))
        .padding(.leading, -TLSpace.page)
        .padding(.trailing, TLSpace.gapL)
    }

    /// 按鈕列（v13 C1）：副按鈕各 `size.bandButtonMinW` 起跳、主按鈕吃滿剩餘。
    ///
    /// 16b 是「加一組 ｜ 下一個」兩顆，16e 中間多插一顆「加練」。固定欄寬的用意是讓
    /// **「加一組」在兩張卡的位置與尺寸完全相同** —— 最後一個動作同時是「再一組」與
    /// 「加練」的最後機會，兩個層級都要在。
    private var actions: some View {
        HStack(spacing: TLSpace.labelGap) {
            // 動作層級：同一個動作再來一組。兩張卡都有。
            outlineButton(oneMoreSetLabel, id: "addSet", action: onOneMoreSet)
            // 訓練層級：開選擇器加一個新動作。只有課表做完（16e）才需要。
            if isPlanFullyDone {
                outlineButton(addExtraLabel, id: "addExtra", action: onAddExtra)
            }
            Button(action: onPrimary) {
                Text(verbatim: primaryTitle)
                    .lineLimit(1)
                    // 16e 三顆並排時主按鈕只剩約 135pt，英文比中文長，留一點縮放空間當保險。
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tlPrimary)
            .accessibilityIdentifier("activeWorkout.completeBand.primary")
        }
    }

    /// 完成區的 outline 副按鈕。
    ///
    /// 寬度是 **`minWidth` 而不是固定寬**：設計稿的 80pt 是照中文字寬訂的，
    /// 英文字長很多，固定寬會直接被截成 `Add…`（實測過），所以讓它只往外長。
    private func outlineButton(_ title: Text, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { title } icon: { Image(systemName: "plus") }
                .font(TLFont.zh(TLFont.rowTitle, .semibold))
                .foregroundStyle(TLColor.sage900)
                .lineLimit(1)
                .padding(.vertical, TLSpace.fieldPadV)
                // 左右內距不能省：中文在 80pt 裡若不留白，字會頂到膠囊框線上。
                .padding(.horizontal, TLSpace.labelGap)
                .frame(minWidth: TLSize.bandButtonMinW)
                .overlay(Capsule().strokeBorder(TLColor.sage400, lineWidth: TLSize.hairlineThick))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityIdentifier("activeWorkout.completeBand.\(id)")
    }
}
