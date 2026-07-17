import HistoryDomain
import SharedKernel
import SwiftUI

struct WorkoutDetailView: View {
    let summary: HistoryWorkoutSummary
    @State private var viewModel: WorkoutDetailViewModel
    @State private var showsDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

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
                            Label("刪除整場紀錄", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("workoutDetail.delete")
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(HistoryFormatting.dayLabel(summary.day))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if viewModel.detail != nil {
                if viewModel.isEditing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { viewModel.cancelEditing() }
                            .accessibilityIdentifier("workoutDetail.cancelEdit")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { Task { await viewModel.save() } }
                            .disabled(!viewModel.hasChanges || viewModel.isSaving)
                            .accessibilityIdentifier("workoutDetail.saveEdit")
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button("編輯") { viewModel.beginEditing() }
                            .accessibilityIdentifier("workoutDetail.edit")
                    }
                }
            }
        }
        // 用 alert 不用 confirmationDialog：iOS 26 的 confirmationDialog 會以帶箭頭的 popover
        // 呈現且錨點不在觸發按鈕上；alert 固定置中、無箭頭。
        .alert("刪除這場訓練紀錄？", isPresented: $showsDeleteConfirm) {
            Button("刪除", role: .destructive) { Task { await viewModel.delete() } }
            Button("取消", role: .cancel) {}
        } message: {
            Text("刪除後無法復原，這場的所有組都會一併移除。")
        }
        .alert(
            "出錯了",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button("好", role: .cancel) {}
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
                    Label("\(minutes) 分鐘", systemImage: "clock")
                }
                Label("\(detail.summary.totalSets) 組", systemImage: "checklist")
                if !HistoryFormatting.feeling(detail.summary.overallFeeling).isEmpty {
                    Text(HistoryFormatting.feeling(detail.summary.overallFeeling))
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            if let note = detail.note {
                Text(note)
            }
        }
    }

    // MARK: - Rows

    private func displayRow(_ set: HistorySetLine) -> some View {
        HStack {
            Text("第\(set.setIndex + 1)組")
                .foregroundStyle(set.status == .skipped ? .secondary : .primary)
            if set.status != .done {
                Text(HistoryFormatting.statusLabel(set.status))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let targetWeight = set.targetWeight, let targetReps = set.targetReps {
                Text("目標 \(targetWeight.displayString)×\(targetReps)")
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
                Text("第\(set.setIndex + 1)組").font(.subheadline.bold())
                HStack(spacing: 20) {
                    stepper(
                        label: "重量",
                        value: draft.weight.displayString,
                        onMinus: { viewModel.bumpWeight(setId: set.id, -1) },
                        onPlus: { viewModel.bumpWeight(setId: set.id, 1) }
                    )
                    stepper(
                        label: "次數",
                        value: "\(draft.reps)",
                        onMinus: { viewModel.bumpReps(setId: set.id, -1) },
                        onPlus: { viewModel.bumpReps(setId: set.id, 1) }
                    )
                }
                Picker("狀態", selection: Binding(
                    get: { draft.status },
                    set: { viewModel.setStatus(setId: set.id, $0) }
                )) {
                    ForEach(WorkoutSetStatus.allCases, id: \.self) { status in
                        Text(HistoryFormatting.statusLabel(status)).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)
        }
    }

    private func stepper(label: String, value: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
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
