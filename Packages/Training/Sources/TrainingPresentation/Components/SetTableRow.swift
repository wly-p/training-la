import DesignSystem
import SharedKernel
import SwiftUI
import TrainingDomain

/// L3 有機體。訓練中的組表一列（11c）。
///
/// 規格：`design-system/organisms/SetTableRow/SetTableRow.spec.md`
///
/// 三種狀態同一個排版，差別在每一欄放什麼：
///   - `done`：勾 ／ 目標 ／ 實際（可撤銷）
///   - `current`：反白圓章 ／ 目標 ／「現在這組」
///   - `upcoming`：淡出的序號 ／ 目標 ／「—」
struct SetTableRow: View {
    let row: ActiveWorkoutViewModel.SetTableRow
    let weightUnit: WeightUnit
    /// 只有剛記錄的那一組能撤銷，所以是 prop 不是元件自己算的。
    let isUndoable: Bool
    let currentSetLabel: Text
    let undoLabel: Text
    let onUndo: () -> Void

    var body: some View {
        TLCard(radius: .inner,
               fill: row.status == .current ? TLColor.neutral300 : TLColor.neutral100) {
            SetTableColumns {
                badge
            } target: {
                targetColumn
            } actual: {
                actualColumn
            }
        }
        .opacity(row.status == .upcoming ? 0.6 : 1)
    }

    @ViewBuilder private var badge: some View {
        switch row.status {
        case .done:
            // 赭紅實心圓＋白勾（11c）；palette 讓勾＝bg 白、圓＝accent，不用綠色。
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(TLColor.bg, TLColor.accent)
        case .current:
            ZStack {
                Circle().fill(TLColor.accent800)
                Text(verbatim: "\(row.setIndex + 1)")
                    .font(TLFont.zh(TLFont.badgeText, .bold))
                    .foregroundStyle(TLColor.bg)
            }
            .frame(width: TLSize.setBadge, height: TLSize.setBadge)
        case .upcoming:
            Text(verbatim: "\(row.setIndex + 1)")
                .font(TLFont.zh(TLFont.badgeText))
                .foregroundStyle(TLColor.neutral500)
        }
    }

    private var targetText: String {
        if let weight = row.target?.targetWeight {
            let reps = row.target?.targetReps.map { " × \($0)" } ?? ""
            return "\(WeightDisplay.weight(weight, in: weightUnit))\(reps)"
        }
        if let reps = row.target?.targetReps { return "× \(reps)" }
        return "—"
    }

    private var targetColumn: some View {
        HStack(spacing: 0) {
            // 11c 的表格不畫「第N組」這行（視覺上是打勾圖示），但測試要能數出「記了幾組」，
            // 所以留一個 0 尺寸的錨點。文字用 verbatim 的序號而非本地化字串——它不會被看到，
            // 進 String Catalog 只是徒增翻譯負擔。
            if row.status == .done {
                testAnchor(id: "activeWorkout.completedSet")
            }
            Text(verbatim: targetText)
                .monospacedDigit()
                .fontWeight(row.status == .current ? .bold : .regular)
                .foregroundStyle(row.status == .current ? TLColor.accent800 : TLColor.neutral600)
        }
    }

    @ViewBuilder private var actualColumn: some View {
        switch row.status {
        case .done:
            HStack(spacing: TLSpace.valueUnitGap) {
                if let actual = row.actual {
                    // 重量／次數是數值資料（verbatim）；「×」不用翻譯，寫死字面量會被 SwiftUI 當
                    // LocalizedStringKey 隱式抽進 String Catalog，故明確 verbatim。
                    Text(verbatim: actual.measurement.displayWeight.map { w in
                        "\(WeightDisplay.weight(w, in: weightUnit)) × \(actual.measurement.displayReps ?? 0)"
                    } ?? "—")
                        .monospacedDigit()
                        .fontWeight(.bold)
                        .foregroundStyle(actual.status == .skipped ? .secondary : .primary)
                }
                // 復原鍵貼著它要撤銷的那一組，且只有剛記錄的那組有。
                // .borderless（而非預設樣式）：預設樣式會讓整列空白處都轉發點擊，
                // 一碰列就誤撤銷。
                if isUndoable {
                    Button(action: onUndo) {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundStyle(TLColor.accent700)   // 換掉系統藍，配色一致
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(undoLabel)
                    .accessibilityIdentifier("activeWorkout.undoSet")
                }
            }
        case .current:
            // 11c 設計稿寫「現在這組」；但「第N組」是 UITests 大量依賴的可見文字，
            // 所以可見顯示改「現在這組」、另外保留一個 0 尺寸的「第N組」節點給測試找。
            HStack(spacing: 0) {
                testAnchor(id: "activeWorkout.currentSet.\(row.setIndex + 1)")
                currentSetLabel
                    .font(TLFont.zh(TLFont.caption))
                    .foregroundStyle(TLColor.accent700)
            }
        case .upcoming:
            Text(verbatim: "—").foregroundStyle(TLColor.neutral500)
        }
    }

    /// 0 尺寸的測試錨點。**這裡的 1 與 0 不是設計值**，是「看不見」的寫法——
    /// 所以刻意不吃 token（見 CHANGELOG：UITest 幽靈錨點）。
    private func testAnchor(id: String) -> some View {
        Text(verbatim: "\(row.setIndex + 1)")
            .font(.system(size: 1))
            .foregroundStyle(.clear)
            .frame(width: 0, height: 0)
            .accessibilityHidden(false)
            .accessibilityIdentifier(id)
    }
}
