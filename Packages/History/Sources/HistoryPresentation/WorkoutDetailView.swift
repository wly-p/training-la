import HistoryDomain
import SharedKernel
import SwiftUI

struct WorkoutDetailView: View {
    let summary: HistoryWorkoutSummary
    @State private var viewModel: WorkoutDetailViewModel
    @State private var showsDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    /// `makeViewModel` 以 autoclosure 存入 @State，確保每個詳情頁只建一次 view model。
    init(summary: HistoryWorkoutSummary, makeViewModel: @autoclosure @escaping () -> WorkoutDetailViewModel) {
        self.summary = summary
        _viewModel = State(wrappedValue: makeViewModel())
    }

    var body: some View {
        List {
            if let detail = viewModel.detail {
                headerSection(detail)
                ForEach(detail.blocks) { block in
                    Section(block.exerciseName) {
                        ForEach(block.sets) { set in
                            if viewModel.isEditing {
                                editRow(set)
                            } else {
                                displayRow(set)
                            }
                        }
                    }
                }
                if !viewModel.isEditing {
                    Section {
                        Button(role: .destructive) {
                            showsDeleteConfirm = true
                        } label: {
                            Label {
                                localText("history.deleteWorkout")
                            } icon: {
                                Image(systemName: "trash")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("workoutDetail.delete")
                    }
                }
            } else {
                ProgressView()
            }
        }
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

    // MARK: - Sections

    private func headerSection(_ detail: HistoryWorkoutDetail) -> some View {
        Section {
            HStack(spacing: 12) {
                if let minutes = detail.summary.durationMinutes {
                    Label {
                        localText("history.minutes \(minutes)")
                    } icon: {
                        Image(systemName: "clock")
                    }
                }
                Label {
                    localText("history.setsSpaced \(detail.summary.totalSets)")
                } icon: {
                    Image(systemName: "checklist")
                }
                if !HistoryFormatting.feeling(detail.summary.overallFeeling).isEmpty {
                    Text(HistoryFormatting.feeling(detail.summary.overallFeeling))
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            if let note = detail.note {
                // 使用者備註是 DB 資料（verbatim）
                Text(verbatim: note)
            }
        }
    }

    // MARK: - Rows

    private func displayRow(_ set: HistorySetLine) -> some View {
        HStack {
            localText("history.setIndex \(set.setIndex + 1)")
                .foregroundStyle(set.status == .skipped ? .secondary : .primary)
            if set.status != .done {
                localText(HistoryFormatting.statusLabel(set.status))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let targetWeight = set.targetWeight, let targetReps = set.targetReps {
                localText("history.target \(targetWeight.displayString) \(targetReps)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text("\(set.weight.displayString) × \(set.reps)")
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func editRow(_ set: HistorySetLine) -> some View {
        if let draft = viewModel.draft(for: set.id) {
            VStack(alignment: .leading, spacing: 10) {
                localText("history.setIndex \(set.setIndex + 1)").font(.subheadline.bold())
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
            .padding(.vertical, 4)
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
}
