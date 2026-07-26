import DesignSystem
import HistoryDomain
import SharedKernel
import SwiftUI

/// 單場分析（設計稿 11d）：達成摘要卡 ＋ 逐組對照表（差異用符號不用色塊：達標打勾、
/// 超出+1、未達−1）。超過 5 組摘錄「⋯還有 N 組」，點「全部展開」才看完整。
/// 跳過的動作在這裡看得到（標「跳過」）；移除的看不到（見 01-training.md 跳過≠移除）。
struct WorkoutDetailView: View {
    let summary: HistoryWorkoutSummary
    @State private var viewModel: WorkoutDetailViewModel
    @State private var showsDeleteConfirm = false
    @State private var expandedBlocks: Set<Int> = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let collapseThreshold = 5

    /// `makeViewModel` 以 autoclosure 存入 @State，確保每個詳情頁只建一次 view model。
    init(summary: HistoryWorkoutSummary, makeViewModel: @autoclosure @escaping () -> WorkoutDetailViewModel) {
        self.summary = summary
        _viewModel = State(wrappedValue: makeViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let detail = viewModel.detail {
                    VStack(alignment: .leading, spacing: TLSpace.section) {
                        achievementCard(detail)
                        ForEach(detail.blocks) { block in
                            blockSection(block)
                        }
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
                        .font(TLFont.zh(21, .bold))
                        .foregroundStyle(TLColor.text)
                    if let minutes = detail.summary.durationMinutes {
                        localText("history.minutes \(minutes)")
                            .font(TLFont.zh(TLFont.rowSub, .regular))
                            .foregroundStyle(TLColor.neutral600)
                    }
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
                numberStat(value: HistoryFormatting.formatNumber(actualVolume), unit: "kg", label: String(localized: "history.totalVolume", bundle: .module))
                if let targetVolume, targetVolume > 0 {
                    numberStat(
                        value: String(format: "%.0f", actualVolume / targetVolume * 100), unit: "%",
                        label: String(localized: "history.achievementRate", bundle: .module)
                    )
                }
            }
            if let note = detail.note {
                Text(verbatim: note)
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral600)
            }
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.neutral300)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }

    private func numberStat(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            (Text(verbatim: value).font(TLFont.display(24)) + Text(verbatim: " \(unit)").font(TLFont.zh(13, .medium)))
                .foregroundStyle(TLColor.text)
            Text(verbatim: label)
                .font(TLFont.zh(11.5, .regular))
                .foregroundStyle(TLColor.neutral600)
        }
    }

    // MARK: - 逐組對照表

    private func blockSection(_ block: HistoryBlock) -> some View {
        let expanded = expandedBlocks.contains(block.id)
        let visibleSets = expanded ? block.sets : Array(block.sets.prefix(collapseThreshold))
        let remaining = block.sets.count - visibleSets.count
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(Text(verbatim: block.exerciseName))
            TLGroup {
                ForEach(visibleSets) { set in
                    if viewModel.isEditing {
                        editRow(set)
                    } else {
                        displayRow(set)
                    }
                }
                if remaining > 0 {
                    Button {
                        expandedBlocks.insert(block.id)
                    } label: {
                        HStack {
                            localText("history.showMore \(remaining)")
                            Spacer()
                            localText("history.showAll")
                        }
                        .font(TLFont.zh(TLFont.rowSub, .medium))
                        .foregroundStyle(TLColor.accent700)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, TLSpace.rowInset)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    private func displayRow(_ set: HistorySetLine) -> some View {
        HStack {
            localText("history.setIndex \(set.setIndex + 1)")
                .font(TLFont.zh(TLFont.rowTitle))
                .foregroundStyle(set.status == .skipped ? TLColor.neutral500 : TLColor.text)
            if set.status != .done {
                localText(HistoryFormatting.statusLabel(set.status))
                    .font(TLFont.zh(10.5, .semibold))
                    .foregroundStyle(TLColor.neutral500)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(TLColor.neutral200))
            }
            Spacer()
            if let targetWeight = set.targetWeight, let targetReps = set.targetReps {
                localText("history.target \(targetWeight.displayString) \(targetReps)")
                    .font(TLFont.zh(11.5, .regular))
                    .foregroundStyle(TLColor.neutral500)
            }
            Text(verbatim: "\(set.weight.displayString) × \(set.reps)")
                .font(TLFont.display(15))
                .foregroundStyle(TLColor.text)
            diffMark(set)
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.vertical, 2)
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

    @ViewBuilder
    private func editRow(_ set: HistorySetLine) -> some View {
        if let draft = viewModel.draft(for: set.id) {
            VStack(alignment: .leading, spacing: 10) {
                localText("history.setIndex \(set.setIndex + 1)").font(TLFont.zh(TLFont.rowTitle, .bold))
                HStack(spacing: 20) {
                    stepper(
                        label: "history.weight",
                        value: draft.weight.displayString,
                        onMinus: { viewModel.bumpWeight(setId: set.id, -1) },
                        onPlus: { viewModel.bumpWeight(setId: set.id, 1) }
                    )
                    stepper(
                        label: "history.reps",
                        value: "\(draft.reps)",
                        onMinus: { viewModel.bumpReps(setId: set.id, -1) },
                        onPlus: { viewModel.bumpReps(setId: set.id, 1) }
                    )
                }
                Picker(selection: Binding(
                    get: { draft.status },
                    set: { viewModel.setStatus(setId: set.id, $0) }
                )) {
                    ForEach(WorkoutSetStatus.allCases, id: \.self) { status in
                        localText(HistoryFormatting.statusLabel(status)).tag(status)
                    }
                } label: {
                    localText("history.status")
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, TLSpace.rowInset)
        }
    }

    private func stepper(label: LocalizedStringKey, value: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            localText(label).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button(action: onMinus) { Image(systemName: "minus.circle") }
                Text(value).monospacedDigit().frame(minWidth: 64)
                Button(action: onPlus) { Image(systemName: "plus.circle") }
            }
            .buttonStyle(.borderless)
            .font(.title3)
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
