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
            // 標題是動作名（DB 資料，verbatim 不本地化）；沒有動作時用本地化的「訓練中」
            .navigationTitle(viewModel.currentExerciseId
                .map { Text(verbatim: viewModel.name(for: $0)) } ?? localText("training.active.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Task { await viewModel.leave() }
                    } label: {
                        localText("training.leave")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showsFinishSheet = true
                    } label: {
                        localText("training.finish")
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
                // 切回前景：補算剩餘秒數並重啟 ticking；進背景：停掉 ticking，
                // 避免回前景時補跑「到點前景提醒」與背景已投遞的通知重複。
                if phase == .active {
                    viewModel.enterForeground()
                } else {
                    viewModel.suspendRestTicking()
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.restRemaining != nil, !viewModel.restEnded {
                    restBar
                }
            }
            .alert(localText("training.restOver"), isPresented: Binding(
                get: { viewModel.showsRestEndedAlert },
                set: { if !$0 { viewModel.dismissRest() } }
            )) {
                Button { viewModel.dismissRest() } label: { localText("training.startNextSet") }
            } message: {
                localText("training.restOver.message")
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
            localText("training.error"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button(role: .cancel) {} label: { localText("training.ok") }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var exerciseCompleteCard: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                // 表情符號無需翻譯（verbatim），避免被隱式當 LocalizedStringKey 抽進 String Catalog。
                Text(verbatim: viewModel.isPlanFullyDone ? "🎉" : "💪")
                    .font(.system(size: 44))
                (viewModel.isPlanFullyDone
                    ? localText("training.planComplete")
                    : localText("training.exerciseDone \(viewModel.completedExerciseName)"))
                    .font(.title2.bold())
                if viewModel.isPlanFullyDone {
                    localText("training.planAllFinished")
                        .foregroundStyle(.secondary)
                    Button {
                        viewModel.dismissExerciseComplete()
                        showsFinishSheet = true
                    } label: {
                        localText("training.finish")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    localText("training.upNext \(viewModel.nextPlannedName ?? "")")
                        .foregroundStyle(.secondary)
                    Button {
                        viewModel.dismissExerciseComplete()
                        Task { await viewModel.advanceToNextPlanned() }
                    } label: {
                        Label {
                            localText("training.nextExercise")
                        } icon: {
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button {
                    viewModel.continueSameExercise()
                } label: {
                    localText("training.oneMoreSet")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
                // 卡片蓋住整個畫面，記錄區的「復原上一組」在底下點不到；
                // 誤按最後一組時這裡是唯一的出口，故卡片自己也要開一個。
                if viewModel.canUndoLastSet {
                    Button {
                        Task { await viewModel.undoLastSet() }
                    } label: {
                        localText("training.undoFromCard")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("activeWorkout.undoSetFromCard")
                }
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
            Label {
                localText("training.pickToStart")
            } icon: {
                Image(systemName: "dumbbell")
            }
        } actions: {
            Button { showsExercisePicker = true } label: { localText("training.addExercise") }
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
                localText("training.resting").font(.caption).foregroundStyle(.secondary)
                Text(restClock(viewModel.restRemaining ?? 0))
                    .font(.title.bold().monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            Button {
                viewModel.adjustRest(15)
            } label: {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            Button { viewModel.dismissRest() } label: { localText("training.skipRest") }
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
            if let summary = viewModel.lastSummary(for: exerciseId) {
                Section {
                    localText("training.lastTime \(summary)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(viewModel.currentBlockSets) { set in
                    HStack {
                        Image(systemName: set.status == .done ? "checkmark.circle.fill" : "arrow.right.circle")
                            .foregroundStyle(set.status == .done ? .green : .secondary)
                        localText("training.setIndex \(set.setIndex + 1)")
                        Spacer()
                        // 重量／次數是數值資料（verbatim）；「×」不用翻譯，寫死字面量會被 SwiftUI 當
                        // LocalizedStringKey 隱式抽進 String Catalog，故明確 verbatim（見 History 同類註解）。
                        Text(verbatim: "\(WeightDisplay.weight(set.weight)) × \(set.reps)")
                            .monospacedDigit()
                            .foregroundStyle(set.status == .skipped ? .secondary : .primary)
                        // 復原鍵貼著它要撤銷的那一組，且只有剛記錄的那組有。
                        // .borderless（而非預設樣式）：預設樣式會讓整列空白處都轉發點擊，
                        // 一碰列就誤撤銷——同 bug③ 的教訓。
                        if viewModel.isUndoable(setId: set.id) {
                            Button {
                                Task { await viewModel.undoLastSet() }
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .buttonStyle(.borderless)
                            .padding(.leading, 4)
                            .accessibilityLabel(localText("training.undoLastSet"))
                            .accessibilityIdentifier("activeWorkout.undoSet")
                        }
                    }
                }
                currentSetEditor
            } header: {
                localText("training.setIndex \(viewModel.currentBlockSets.count + 1)")
            }

            Section {
                if viewModel.isFollowingPlan {
                    if viewModel.upcomingExercises.isEmpty {
                        Label {
                            localText("training.planAllDone")
                        } icon: {
                            Image(systemName: "checkmark.circle")
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        // 未做的課表動作：點一下直接跳過去做；編輯模式可拖拉調整順序。
                        ForEach(viewModel.upcomingExercises) { exercise in
                            Button {
                                Task { await viewModel.select(exerciseId: exercise.id) }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                                    // 動作名是 DB 資料（verbatim）
                                    Text(verbatim: exercise.name)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .onMove { viewModel.moveUpcoming(fromOffsets: $0, toOffset: $1) }
                    }
                    Button {
                        showsExercisePicker = true
                    } label: {
                        Label {
                            localText("training.addAnother")
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                } else {
                    Button {
                        showsExercisePicker = true
                    } label: {
                        Label {
                            localText("training.nextExercise")
                        } icon: {
                            Image(systemName: "arrow.right")
                        }
                    }
                }
            } header: {
                if viewModel.isFollowingPlan && !viewModel.upcomingExercises.isEmpty {
                    HStack {
                        localText("training.upcoming")
                        #if os(iOS)
                        if viewModel.upcomingExercises.count > 1 {
                            Spacer()
                            EditButton().textCase(nil)   // 進編輯模式出現拖拉握把
                        }
                        #endif
                    }
                }
            }

            if !viewModel.otherBlocks.isEmpty {
                Section {
                    ForEach(viewModel.otherBlocks) { block in
                        Button {
                            Task { await viewModel.select(exerciseId: block.exerciseId) }
                        } label: {
                            HStack {
                                Text(verbatim: viewModel.name(for: block.exerciseId))
                                Spacer()
                                Text(WeightDisplay.summary(of: block.sets))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    localText("training.otherExercises")
                }
            }
        }
    }

    private var currentSetEditor: some View {
        VStack(spacing: 16) {
            if let target = viewModel.currentTarget, let weight = target.targetWeight {
                let detail = target.targetReps.map { " × \($0)" } ?? ""
                let value = "\(WeightDisplay.weight(weight))\(detail)"
                localText("training.target \(value)")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
            }
            HStack(spacing: 24) {
                stepper(
                    label: "training.weight",
                    value: "\(WeightDisplay.value(viewModel.draftWeightValue)) \(viewModel.draftWeightUnit.rawValue)",
                    idPrefix: "activeWorkout.weight",
                    onMinus: { viewModel.bumpWeight(-1) },
                    onPlus: { viewModel.bumpWeight(1) }
                )
                stepper(
                    label: "training.reps",
                    value: "\(viewModel.draftReps)",
                    idPrefix: "activeWorkout.reps",
                    onMinus: { viewModel.bumpReps(-1) },
                    onPlus: { viewModel.bumpReps(1) }
                )
            }
            Picker(selection: $viewModel.draftWeightUnit) {
                ForEach(WeightUnit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            } label: {
                localText("training.unit")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 160)
            .accessibilityIdentifier("activeWorkout.unitPicker")

            Button {
                Task { await viewModel.completeCurrentSet() }
            } label: {
                Label {
                    localText("training.completeSet")
                } icon: {
                    Image(systemName: "checkmark")
                }
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("activeWorkout.completeSet")

            // .bordered（而非預設樣式）：這格是含多個控制項的 List cell，預設樣式的按鈕
            // 會讓整個 cell 空白處都轉發點擊給它，導致誤觸「跳過此組」多記一組。侷限點擊區才不誤觸。
            HStack(spacing: 10) {
                Button {
                    Task { await viewModel.skipCurrentSet() }
                } label: {
                    localText("training.skipSet")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("activeWorkout.skipSet")
                if viewModel.restRemaining == nil {
                    Menu {
                        ForEach(restPresets, id: \.self) { sec in
                            Button(restClock(sec)) { viewModel.startManualRest(seconds: sec) }
                        }
                    } label: {
                        Image(systemName: "timer") // 純圖示：跟「跳過此組」擺一起才不會擠爆這列
                    }
                    .menuStyle(.button)
                    .buttonStyle(.bordered)
                    .accessibilityLabel(localText("training.restTimer"))
                    .accessibilityIdentifier("activeWorkout.restTimer")
                }
            }
            .font(.subheadline)
            .controlSize(.small)
        }
        .padding(.vertical, 8)
    }

    private let restPresets = [30, 60, 90, 120, 150, 180, 240, 300]

    private func stepper(
        label: LocalizedStringKey,
        value: String,
        idPrefix: String,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            localText(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button(action: onMinus) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(idPrefix).minus")
                Text(value)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .frame(minWidth: 72)
                Button(action: onPlus) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(idPrefix).plus")
            }
        }
    }
}
