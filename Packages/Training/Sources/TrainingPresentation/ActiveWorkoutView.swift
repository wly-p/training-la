import SharedKernel
import SwiftUI
import TrainingDomain

public struct ActiveWorkoutView: View {
    @Bindable private var viewModel: ActiveWorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
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
            .onChange(of: scenePhase) { _, phase in
                // 切回前景：用結束時間重算剩餘秒數，補上背景期間經過的時間。
                if phase == .active { viewModel.refreshRest() }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.restRemaining != nil, !viewModel.restEnded {
                    restBar
                }
            }
            .alert("休息結束", isPresented: Binding(
                get: { viewModel.restEnded },
                set: { if !$0 { viewModel.dismissRest() } }
            )) {
                Button("開始下一組") { viewModel.dismissRest() }
            } message: {
                Text("休息時間到了，準備下一組。")
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
        }
        // 動作完成卡片：用 overlay 而非 sheet，避免與其他 sheet 疊放衝突，
        // 也讓「結束訓練」能無縫接到結束 sheet。
        .overlay {
            if viewModel.showExerciseComplete {
                exerciseCompleteCard
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.showExerciseComplete)
        // 錯誤彈窗掛在 NavigationStack 外層：與「休息結束」彈窗分屬不同 view，
        // 避免同一 view 上兩個 .alert 互相壓制。
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

    private var exerciseCompleteCard: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Text(viewModel.isPlanFullyDone ? "🎉" : "💪")
                    .font(.system(size: 44))
                Text(viewModel.isPlanFullyDone ? "課表完成" : "\(viewModel.completedExerciseName) 完成")
                    .font(.title2.bold())
                if viewModel.isPlanFullyDone {
                    Text("所有課表動作都做完了")
                        .foregroundStyle(.secondary)
                    Button {
                        viewModel.dismissExerciseComplete()
                        showsFinishSheet = true
                    } label: {
                        Text("結束訓練")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("接下來：\(viewModel.nextPlannedName ?? "")")
                        .foregroundStyle(.secondary)
                    Button {
                        viewModel.dismissExerciseComplete()
                        Task { await viewModel.advanceToNextPlanned() }
                    } label: {
                        Label("下一個動作", systemImage: "arrow.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("再做一組") {
                    viewModel.continueSameExercise()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
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

    private var restBar: some View {
        HStack(spacing: 16) {
            Button {
                viewModel.adjustRest(-15)
            } label: {
                Image(systemName: "minus.circle.fill").font(.title2)
            }
            VStack(spacing: 0) {
                Text("休息中").font(.caption).foregroundStyle(.secondary)
                Text(restClock(viewModel.restRemaining ?? 0))
                    .font(.title.bold().monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            Button {
                viewModel.adjustRest(15)
            } label: {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            Button("跳過") { viewModel.dismissRest() }
                .font(.subheadline)
        }
        .padding()
        .background(.regularMaterial)
    }

    private func restClock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
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
                if viewModel.isFollowingPlan {
                    if let nextName = viewModel.nextPlannedName {
                        Button {
                            Task { await viewModel.advanceToNextPlanned() }
                        } label: {
                            Label("下一個動作：\(nextName)", systemImage: "arrow.right")
                        }
                    } else {
                        Label("課表動作都做完了，可結束或加練", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        showsExercisePicker = true
                    } label: {
                        Label("加入其他動作", systemImage: "plus")
                    }
                } else {
                    Button {
                        showsExercisePicker = true
                    } label: {
                        Label("下一個動作", systemImage: "arrow.right")
                    }
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

            HStack(spacing: 20) {
                Button("跳過此組") {
                    Task { await viewModel.skipCurrentSet() }
                }
                if viewModel.restRemaining == nil {
                    Menu {
                        ForEach(restPresets, id: \.self) { sec in
                            Button(restClock(sec)) { viewModel.startRest(seconds: sec) }
                        }
                    } label: {
                        Label("休息計時", systemImage: "timer")
                    }
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private let restPresets = [30, 60, 90, 120, 150, 180, 240, 300]

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
