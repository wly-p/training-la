import SharedKernel
import SwiftUI
import TrainingDomain

public struct ActiveWorkoutView: View {
    @Bindable private var viewModel: ActiveWorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsExercisePicker = false
    @State private var showsFinishSheet = false

    public init(viewModel: ActiveWorkoutViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let exerciseId = viewModel.currentExerciseId {
                    recordingContent(exerciseId: exerciseId)
                } else {
                    emptyState
                }
            }
            .navigationTitle(viewModel.currentExerciseId.map { viewModel.name(for: $0) } ?? "訓練中")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("離開") {
                        Task { await viewModel.leave() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("結束訓練") {
                        showsFinishSheet = true
                    }
                    .disabled(viewModel.totalSetCount == 0)
                }
            }
            .task {
                await viewModel.onAppear()
                if viewModel.currentExerciseId == nil {
                    showsExercisePicker = true
                }
            }
            .onChange(of: viewModel.isDismissed) { _, dismissed in
                if dismissed { dismiss() }
            }
            .sheet(isPresented: $showsExercisePicker) {
                ExercisePickerView(catalog: viewModel.catalog) { exercise in
                    Task { await viewModel.select(exerciseId: exercise.id) }
                }
            }
            .sheet(isPresented: $showsFinishSheet) {
                FinishWorkoutSheet(
                    durationMinutes: viewModel.durationMinutes,
                    totalSets: viewModel.totalSetCount
                ) { feeling, note in
                    await viewModel.finish(feeling: feeling, note: note)
                }
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
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("選一個動作開始", systemImage: "dumbbell")
        } actions: {
            Button("加入動作") { showsExercisePicker = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func recordingContent(exerciseId: UUID) -> some View {
        List {
            if let ghost = viewModel.ghostText(for: exerciseId) {
                Section {
                    Text(ghost)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(viewModel.currentBlockSets) { set in
                    HStack {
                        Image(systemName: set.status == .done ? "checkmark.circle.fill" : "arrow.right.circle")
                            .foregroundStyle(set.status == .done ? .green : .secondary)
                        Text("第\(set.setIndex + 1)組")
                        Spacer()
                        Text("\(WeightDisplay.weight(set.weight)) × \(set.reps)")
                            .monospacedDigit()
                            .foregroundStyle(set.status == .skipped ? .secondary : .primary)
                    }
                }
                currentSetEditor
            } header: {
                Text("第\(viewModel.currentBlockSets.count + 1)組")
            }

            Section {
                Button {
                    showsExercisePicker = true
                } label: {
                    Label("下一個動作", systemImage: "arrow.right")
                }
            }

            if !viewModel.otherBlocks.isEmpty {
                Section("本場其他動作") {
                    ForEach(viewModel.otherBlocks) { block in
                        Button {
                            Task { await viewModel.select(exerciseId: block.exerciseId) }
                        } label: {
                            HStack {
                                Text(viewModel.name(for: block.exerciseId))
                                Spacer()
                                Text(WeightDisplay.summary(of: block.sets))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var currentSetEditor: some View {
        VStack(spacing: 16) {
            if let target = viewModel.currentTarget, let weight = target.targetWeight {
                Text("目標：\(WeightDisplay.weight(weight))\(target.targetReps.map { " × \($0)" } ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
            }
            HStack(spacing: 24) {
                stepper(
                    label: "重量",
                    value: "\(WeightDisplay.value(viewModel.draftWeightValue)) \(viewModel.draftWeightUnit.rawValue)",
                    onMinus: { viewModel.bumpWeight(-1) },
                    onPlus: { viewModel.bumpWeight(1) }
                )
                stepper(
                    label: "次數",
                    value: "\(viewModel.draftReps)",
                    onMinus: { viewModel.bumpReps(-1) },
                    onPlus: { viewModel.bumpReps(1) }
                )
            }
            Picker("單位", selection: $viewModel.draftWeightUnit) {
                ForEach(WeightUnit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 160)

            Button {
                Task { await viewModel.completeCurrentSet() }
            } label: {
                Label("完成此組", systemImage: "checkmark")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)

            Button("跳過此組") {
                Task { await viewModel.skipCurrentSet() }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func stepper(
        label: String,
        value: String,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button(action: onMinus) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                Text(value)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .frame(minWidth: 72)
                Button(action: onPlus) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
