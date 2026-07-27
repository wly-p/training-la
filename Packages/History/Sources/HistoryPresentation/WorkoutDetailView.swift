import DesignSystem
import HistoryDomain
import SharedKernel
import SwiftUI

/// 單場分析（設計稿 11d）：kicker ＋ 達成摘要卡（總量 實際/目標、達成率綠色）＋ 逐組對照單一表格
/// （欄名 動作／目標／實際，左欄「動作名 組N」，差異用符號不用色塊：達標打勾 sage、超出 +N、
/// 未達 −N danger-700）。整場超過 5 組摘錄「⋯還有 N 組」，點「全部展開」才看完整。
/// 跳過的動作在這裡看得到（標「跳過」）；移除的看不到（見 01-training.md 跳過≠移除）。
struct WorkoutDetailView: View {
    let summary: HistoryWorkoutSummary
    @State private var viewModel: WorkoutDetailViewModel
    @State private var showsDeleteConfirm = false
    @State private var expandedAll = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let collapseThreshold = 5
    private let targetColWidth: CGFloat = 78
    private let actualColWidth: CGFloat = 78
    private let diffColWidth: CGFloat = 26

    /// `makeViewModel` 以 autoclosure 存入 @State，確保每個詳情頁只建一次 view model。
    init(summary: HistoryWorkoutSummary, makeViewModel: @autoclosure @escaping () -> WorkoutDetailViewModel) {
        self.summary = summary
        _viewModel = State(wrappedValue: makeViewModel())
    }

    /// 攤平所有組（帶動作名），供單一對照表逐列呈現。
    private struct FlatLine: Identifiable {
        let exerciseName: String
        let set: HistorySetLine
        var id: UUID { self.set.id }
    }

    private func flatLines(_ detail: HistoryWorkoutDetail) -> [FlatLine] {
        detail.blocks.flatMap { block in
            block.sets.map { FlatLine(exerciseName: block.exerciseName, set: $0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let detail = viewModel.detail {
                    VStack(alignment: .leading, spacing: TLSpace.section) {
                        VStack(alignment: .leading, spacing: TLSpace.gapM) {
                            localText("history.detail.kicker")
                                .font(TLFont.zh(TLFont.kicker, .semibold))
                                .tracking(TLFont.kickerTracking)
                                .textCase(.uppercase)
                                .foregroundStyle(TLColor.neutral500)
                            achievementCard(detail)
                        }
                        comparisonSection(detail)
                        if !viewModel.isEditing {
                            deleteRow
                        }
                    }
                    .padding(.horizontal, TLSpace.page)
                    .padding(.top, TLSpace.section)
                } else {
                    ProgressView().padding(.top, 60).frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 40)
        }
        .background(TLColor.bg.ignoresSafeArea())
        .navigationTitle(HistoryFormatting.dayLabel(summary.day, locale: locale))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if viewModel.detail != nil {
                if viewModel.isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { viewModel.cancelEditing() } label: { localText("history.cancel") }
                            .accessibilityIdentifier("workoutDetail.cancelEdit")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button { Task { await viewModel.save() } } label: { localText("history.done") }
                            .disabled(!viewModel.hasChanges || viewModel.isSaving)
                            .accessibilityIdentifier("workoutDetail.saveEdit")
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button { viewModel.beginEditing() } label: { localText("history.edit") }
                            .accessibilityIdentifier("workoutDetail.edit")
                    }
                }
            }
        }
        // 用 alert 不用 confirmationDialog：iOS 26 的 confirmationDialog 會以帶箭頭的 popover
        // 呈現且錨點不在觸發按鈕上；alert 固定置中、無箭頭。
        .alert(localText("history.deleteConfirm.title"), isPresented: $showsDeleteConfirm) {
            Button(role: .destructive) { Task { await viewModel.delete() } } label: { localText("history.delete") }
            Button(role: .cancel) {} label: { localText("history.cancel") }
        } message: {
            localText("history.deleteConfirm.message")
        }
        .alert(
            localText("history.error"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button(role: .cancel) {} label: { localText("history.ok") }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task { await viewModel.load() }
        .onChange(of: viewModel.isDeleted) { _, deleted in
            if deleted { dismiss() }
        }
    }

    // MARK: - 達成摘要卡

    private func achievementCard(_ detail: HistoryWorkoutDetail) -> some View {
        let (achievedCount, totalCount) = HistoryFormatting.achievedSetCount(detail.blocks)
        let (actualVolume, targetVolume) = HistoryFormatting.totalVolume(detail.blocks)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: detail.summary.name ?? String(localized: "history.freeTraining", bundle: .module))
                        .font(TLFont.zh(26, .bold))
                        .foregroundStyle(TLColor.text)
                    Text(verbatim: subline(detail))
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral600)
                }
                Spacer()
                if totalCount > 0 {
                    localText("history.achievedCount \(achievedCount) \(totalCount)")
                        .font(TLFont.zh(TLFont.rowSub, .semibold))
                        .foregroundStyle(TLColor.sage800)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(TLColor.sage200))
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 28) {
                volumeStat(actual: actualVolume, target: targetVolume)
                if let targetVolume, targetVolume > 0 {
                    achievementRateStat(rate: actualVolume / targetVolume * 100)
                }
            }
            if let note = detail.note {
                Text(verbatim: note)
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral600)
            }
        }
        .padding(TLSpace.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TLColor.neutral300)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }

    /// 副行「7/27 (週一) · 42 分」：日期 ＋ 時長（沒時長只給日期）。
    private func subline(_ detail: HistoryWorkoutDetail) -> String {
        let day = HistoryFormatting.dayLabel(summary.day, locale: locale)
        guard let minutes = detail.summary.durationMinutes else { return day }
        return day + " · " + String(format: String(localized: "history.minutes \(minutes)", bundle: .module))
    }

    /// 總量：有目標時「實際 / 目標 kg」（實際大黑、目標小灰）；無目標只顯示「實際 kg」。
    private func volumeStat(actual: Double, target: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            localText(target != nil && target! > 0 ? "history.volumeActualTarget" : "history.totalVolume")
                .font(TLFont.zh(11.5, .regular))
                .foregroundStyle(TLColor.neutral600)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(verbatim: HistoryFormatting.formatNumber(actual))
                    .font(TLFont.display(28))
                    .foregroundStyle(TLColor.text)
                if let target, target > 0 {
                    Text(verbatim: " / \(HistoryFormatting.formatNumber(target)) kg")
                        .font(TLFont.zh(13, .medium))
                        .foregroundStyle(TLColor.neutral500)
                } else {
                    Text(verbatim: " kg")
                        .font(TLFont.zh(13, .medium))
                        .foregroundStyle(TLColor.neutral500)
                }
            }
        }
    }

    /// 達成率：sage 綠色大字（全 App 唯一「刻意安排重量才有意義」的正向指標）。
    private func achievementRateStat(rate: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            localText("history.achievementRate")
                .font(TLFont.zh(11.5, .regular))
                .foregroundStyle(TLColor.neutral600)
            (Text(verbatim: String(format: "%.0f", rate)).font(TLFont.display(28))
                + Text(verbatim: " %").font(TLFont.zh(13, .medium)))
                .foregroundStyle(TLColor.sage700)
        }
    }

    // MARK: - 逐組對照（單一表格）

    private func comparisonSection(_ detail: HistoryWorkoutDetail) -> some View {
        let lines = flatLines(detail)
        let visible = (viewModel.isEditing || expandedAll) ? lines : Array(lines.prefix(collapseThreshold))
        let remaining = lines.count - visible.count
        return VStack(alignment: .leading, spacing: TLSpace.gapS) {
            SectionHeader(localText("history.setComparison"))
            TLGroup {
                if !viewModel.isEditing {
                    columnHeader
                }
                ForEach(visible) { line in
                    if viewModel.isEditing {
                        editRow(line)
                    } else {
                        displayRow(line)
                    }
                }
                if remaining > 0 {
                    Button {
                        expandedAll = true
                    } label: {
                        HStack {
                            localText("history.showMore \(remaining)")
                            Spacer()
                            localText("history.showAll")
                        }
                        .font(TLFont.zh(TLFont.rowSub, .medium))
                        .foregroundStyle(TLColor.accent700)
                        .padding(.horizontal, TLSpace.rowInset)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            localText("history.col.exercise")
                .frame(maxWidth: .infinity, alignment: .leading)
            localText("history.col.target")
                .frame(width: targetColWidth, alignment: .trailing)
            localText("history.col.actual")
                .frame(width: actualColWidth, alignment: .trailing)
            Color.clear.frame(width: diffColWidth)
        }
        .font(.caption2.weight(.semibold))
        .textCase(.uppercase)
        .foregroundStyle(TLColor.neutral500)
        .padding(.horizontal, TLSpace.rowInset)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    private func displayRow(_ line: FlatLine) -> some View {
        let set = line.set
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                // 動作名獨立一個 Text（粗黑，UITest 靠它找動作），「組 N」另一個 Text（細灰）——
                // 對齊設計稿 11d 的兩段式樣式。
                Text(verbatim: line.exerciseName)
                    .font(TLFont.zh(TLFont.rowTitle, .semibold))
                    .foregroundStyle(set.status == .skipped ? TLColor.neutral500 : TLColor.text)
                    .lineLimit(1)
                localText("history.setN \(set.setIndex + 1)")
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral500)
                if set.status != .done {
                    localText(HistoryFormatting.statusLabel(set.status))
                        .font(TLFont.zh(10.5, .semibold))
                        .foregroundStyle(TLColor.neutral500)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(TLColor.neutral200))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: targetText(set))
                .font(TLFont.display(13.5))
                .foregroundStyle(TLColor.neutral500)
                .frame(width: targetColWidth, alignment: .trailing)
            Text(verbatim: "\(set.weight.displayString) × \(set.reps)")
                .font(TLFont.display(15))
                .foregroundStyle(TLColor.text)
                .frame(width: actualColWidth, alignment: .trailing)
            diffMark(set)
                .frame(width: diffColWidth, alignment: .trailing)
        }
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: TLSize.row)
    }

    private func targetText(_ set: HistorySetLine) -> String {
        guard let tw = set.targetWeight, let tr = set.targetReps else { return "—" }
        return "\(tw.displayString) × \(tr)"
    }

    /// 差異用符號不用色塊：達標打勾(sage)、超出+N、未達−N(danger-700)，沒有目標＝不顯示。
    @ViewBuilder
    private func diffMark(_ set: HistorySetLine) -> some View {
        switch HistoryFormatting.achieved(set) {
        case true:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(TLColor.sage)
        case false:
            let delta = HistoryFormatting.repsDelta(set) ?? 0
            Text(verbatim: delta > 0 ? "+\(delta)" : "\(delta)")
                .font(TLFont.zh(12, .semibold))
                .foregroundStyle(delta > 0 ? TLColor.sage700 : TLColor.danger700)
        case nil:
            EmptyView()
        }
    }

    // MARK: - 逐組編輯（無設計稿；套 DesignSystem 元件，脫離原生藍白 UI）

    @ViewBuilder
    private func editRow(_ line: FlatLine) -> some View {
        let set = line.set
        if let draft = viewModel.draft(for: set.id) {
            VStack(alignment: .leading, spacing: TLSpace.gapM) {
                (Text(verbatim: line.exerciseName).font(TLFont.zh(TLFont.rowTitle, .bold))
                    + Text(verbatim: " ") + localText("history.setN \(set.setIndex + 1)").font(TLFont.zh(TLFont.rowSub, .regular)))
                    .foregroundStyle(TLColor.text)
                HStack(spacing: TLSpace.gapL) {
                    accentStepper(
                        label: "history.weight",
                        value: draft.weight.displayString,
                        onMinus: { viewModel.bumpWeight(setId: set.id, -1) },
                        onPlus: { viewModel.bumpWeight(setId: set.id, 1) }
                    )
                    accentStepper(
                        label: "history.reps",
                        value: "\(draft.reps)",
                        onMinus: { viewModel.bumpReps(setId: set.id, -1) },
                        onPlus: { viewModel.bumpReps(setId: set.id, 1) }
                    )
                }
                TLSegmentedControl(
                    selection: Binding(
                        get: { draft.status },
                        set: { viewModel.setStatus(setId: set.id, $0) }
                    ),
                    options: [
                        .init(.done, localText(HistoryFormatting.statusLabel(.done))),
                        .init(.skipped, localText(HistoryFormatting.statusLabel(.skipped))),
                        .init(.interrupted, localText(HistoryFormatting.statusLabel(.interrupted))),
                    ]
                )
            }
            .padding(.vertical, 12)
            .padding(.horizontal, TLSpace.rowInset)
        }
    }

    private func accentStepper(label: LocalizedStringKey, value: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            localText(label)
                .font(TLFont.zh(11.5, .regular))
                .foregroundStyle(TLColor.neutral500)
            HStack(spacing: 12) {
                Button(action: onMinus) {
                    Image(systemName: "minus.circle.fill").font(.title2).foregroundStyle(TLColor.accent)
                }
                .buttonStyle(.plain)
                Text(value)
                    .font(TLFont.display(20))
                    .monospacedDigit()
                    .foregroundStyle(TLColor.text)
                    .frame(minWidth: 60)
                Button(action: onPlus) {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(TLColor.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var deleteRow: some View {
        TLGroup {
            SettingsRow(
                localText("history.deleteWorkout"),
                role: .destructive,
                onTap: { showsDeleteConfirm = true }
            )
        }
        .accessibilityIdentifier("workoutDetail.delete")
    }
}
