import DesignSystem
import SharedKernel
import SwiftUI
import TrainingDomain

public struct ActiveWorkoutView: View {
    @Bindable private var viewModel: ActiveWorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsExercisePicker = false
    @State private var showsFinishSheet = false
    /// 長按「本場動作」列（13e）選到的目標；非 nil → 彈出中途改課選單。
    @State private var midWorkoutEditTarget: SessionExercise?
    /// 選單裡「換一個動作」點下去後要換的舊動作 id；非 nil → 開選動作 sheet。
    @State private var replacingExerciseId: UUID?

    public init(viewModel: ActiveWorkoutViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let exerciseId = viewModel.currentExerciseId, viewModel.restRemaining != nil {
                    // 休息是獨立狀態，不是角落的小計時器（13c）：整個畫面讓給它，不是疊在組表上的小條。
                    // 條件故意不含 !restEnded——倒數歸零那一刻要讓「休息結束」彈窗蓋在這層上面，
                    // 若這裡同時把畫面切回 recordingContent，跟 alert 的 isPresented 在同一個 transaction
                    // 搶著改畫面，SwiftUI 有時會把剛觸發的 alert 吞掉不顯示。等使用者按了彈窗、
                    // dismissRest() 清空 restRemaining，才真正切回組表。
                    restFullScreen(exerciseId: exerciseId)
                } else if let exerciseId = viewModel.currentExerciseId {
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
            .confirmationDialog(
                Text(verbatim: midWorkoutEditTarget?.name ?? ""),
                isPresented: Binding(
                    get: { midWorkoutEditTarget != nil },
                    set: { if !$0 { midWorkoutEditTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                midWorkoutEditMenu
            } message: {
                localText("training.edit.hint")
            }
            .sheet(isPresented: Binding(
                get: { replacingExerciseId != nil },
                set: { if !$0 { replacingExerciseId = nil } }
            )) {
                if let oldId = replacingExerciseId {
                    ExercisePickerView(catalog: viewModel.catalog) { newExercise in
                        Task { await viewModel.replaceExercise(oldId, with: newExercise.id) }
                    }
                }
            }
            .sheet(isPresented: $showsFinishSheet) {
                FinishWorkoutSheet(
                    workout: viewModel.workout,
                    workoutName: viewModel.blueprint?.name,
                    exerciseName: { viewModel.name(for: $0) },
                    detectPersonalRecords: { await viewModel.detectPersonalRecordsForThisSession() },
                    onFinish: { feeling, note in
                        await viewModel.finish(feeling: feeling, note: note)
                    },
                    onDiscard: {
                        await viewModel.discardCurrentWorkout()
                    }
                )
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

    /// 休息中全螢幕（13c）：休息是獨立狀態，不是角落的小計時器，這 90 秒沒別的事可做，
    /// 畫面就該以它為主角。計時不擋操作——「接下來」卡片可先調整下一組的重量/次數，
    /// 底部按鈕可提早開始，不用等倒數。
    private func restFullScreen(exerciseId: UUID) -> some View {
        let doneCount = viewModel.currentBlockSets.count
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 動作名已經是 navigationTitle（native 大標題），這裡不重複，只加課表進度 kicker。
                if let plannedCount = viewModel.blueprint?.exercises.first(where: { $0.exerciseId == exerciseId })?.setCount {
                    Text(verbatim: String(
                        format: String(localized: "training.rest.doneOfTotal %lld %lld", bundle: .module),
                        doneCount, plannedCount
                    ))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(TLColor.accent600)
                }
                restTimerBlock
                nextSetCard
                Spacer(minLength: 0)
                Button {
                    viewModel.dismissRest()
                } label: {
                    Text(verbatim: String(
                        format: String(localized: "training.rest.startEarly %lld", bundle: .module), doneCount + 1
                    ))
                }
                .buttonStyle(.tlPrimary)
            }
            .padding(TLSpace.page)
        }
        .background(TLColor.bg.ignoresSafeArea())
    }

    private var restTimerBlock: some View {
        let remaining = viewModel.restRemaining ?? 0
        return VStack(spacing: 16) {
            localText("training.resting")
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(TLColor.accent800)
            Text(verbatim: restClock(remaining))
                .font(TLFont.display(56))
                .foregroundStyle(TLColor.accent900)
            ProgressView(value: restProgress)
                .tint(TLColor.accent700)
            localText("training.restTimer")
                .font(.caption)
                .foregroundStyle(TLColor.accent700)
            HStack(spacing: 10) {
                restPill(String(format: String(localized: "training.rest.adjust %lld", bundle: .module), 30)) {
                    viewModel.adjustRest(30)
                }
                restPill(String(format: String(localized: "training.rest.adjust %lld", bundle: .module), -30)) {
                    viewModel.adjustRest(-30)
                }
                Button {
                    viewModel.dismissRest()
                } label: {
                    localText("training.skipRest")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.tlPrimary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(TLSpace.rowInset)
        .frame(maxWidth: .infinity)
        .background(TLColor.accent200)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }

    /// 進度條：剩餘 / 這段休息的起始總長，隨時間往 1 走（1＝快結束）。
    private var restProgress: Double {
        guard let remaining = viewModel.restRemaining, let total = viewModel.restTotalSeconds, total > 0 else { return 1 }
        return 1 - (Double(remaining) / Double(total))
    }

    private func restPill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(TLColor.accent800)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(TLColor.bg)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// 「接下來·第N組」卡：休息中提早看到、也能先調——目標次數/上一組實際次數/重量，
    /// 重量沿用 draftWeightValue（appendSet 後 prefillDraft 已經預填好下一組的值）。
    private var nextSetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: String(
                format: String(localized: "training.rest.next %lld", bundle: .module),
                viewModel.currentBlockSets.count + 1
            ))
            .font(.caption)
            .foregroundStyle(TLColor.neutral500)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let exerciseId = viewModel.currentExerciseId {
                        Text(verbatim: viewModel.name(for: exerciseId))
                            .font(.headline)
                    }
                    HStack(spacing: 6) {
                        if let targetReps = viewModel.currentTarget?.targetReps {
                            Text(verbatim: String(format: String(localized: "training.rest.targetReps %lld", bundle: .module), targetReps))
                        }
                        if let lastReps = viewModel.currentBlockSets.last?.reps {
                            Text(verbatim: String(format: String(localized: "training.rest.lastReps %lld", bundle: .module), lastReps))
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(TLColor.neutral600)
                }
                Spacer()
                Text(verbatim: "\(WeightDisplay.value(viewModel.draftWeightValue)) \(viewModel.draftWeightUnit.rawValue)")
                    .font(TLFont.display(28))
                    .foregroundStyle(TLColor.text)
            }
            HStack(spacing: 8) {
                restPill("−\(viewModel.draftWeightUnit == .kg ? "2.5" : "5")") { viewModel.bumpWeight(-1) }
                restPill("+\(viewModel.draftWeightUnit == .kg ? "2.5" : "5")") { viewModel.bumpWeight(1) }
            }
            localText("training.rest.tapHint")
                .font(.caption2)
                .foregroundStyle(TLColor.neutral500)
        }
        .padding(TLSpace.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
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
                ForEach(viewModel.setTableRows) { row in
                    setTableRow(row)
                }
                currentSetEditor
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } header: {
                setTableHeader
            } footer: {
                nextSetPreviewFooter
            }

            // 本場動作：一份順序清單，涵蓋已完成／進行中（高亮）／做一半／未開始。
            // 點任一列＝切到那個動作（高亮就地移動，不會有東西「不見」）；
            // 未開始的列可長按拖拉調整順序（無需編輯模式）。
            //
            // 13e 中途改課設計稿寫「長按這一列」開選單，但這一列已經是 List 的 onMove 拖曳
            // 目標（長按＝進入拖曳）——兩個手勢搶同一個「長按」會互相干擾、行為不穩定。改用
            // 列尾的「…」鈕當入口：一樣是「手指已經在這一列上」，不用跳到右上角選單，
            // 但不會跟既有的拖曳排序手勢衝突。
            Section {
                ForEach(viewModel.sessionSequence) { exercise in
                    Button {
                        Task { await viewModel.select(exerciseId: exercise.id) }
                    } label: {
                        HStack(spacing: 10) {
                            sessionStatusIcon(exercise.status)
                                .frame(width: 20)
                            // 動作名是 DB 資料（verbatim）；當前動作加粗
                            Text(verbatim: exercise.name)
                                .fontWeight(exercise.isCurrent ? .semibold : .regular)
                            Spacer()
                            if let progress = sessionProgress(exercise) {
                                Text(verbatim: progress)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            // .borderless（而非預設樣式）：跟 undo 鍵同一個理由——這格是巢狀在
                            // 一個大範圍 Button 裡的控制項，預設樣式會讓點擊范圍互相搶奪。
                            Button {
                                midWorkoutEditTarget = exercise
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(localText("training.edit.menu"))
                            .accessibilityIdentifier("activeWorkout.midWorkoutEdit")
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(exercise.isCurrent ? Color.accentColor.opacity(0.12) : nil)
                    .moveDisabled(exercise.status != .upcoming)   // 只有未開始的能拖拉調序
                }
                .onMove { viewModel.reorderSession(fromOffsets: $0, toOffset: $1) }

                Button {
                    showsExercisePicker = true
                } label: {
                    Label {
                        localText("training.addAnother")
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
            } header: {
                localText("training.sessionExercises")
            }
        }
    }

    /// 組表（3b+11c）標頭：動作級摘要（幾組·強度／算式）＋「組/目標/實際」欄名。
    private var setTableHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let summary = exerciseTableSummary {
                Text(verbatim: summary)
                    .font(.footnote)
                    .foregroundStyle(TLColor.neutral600)
            }
            HStack {
                localText("training.table.set")
                Spacer()
                localText("training.table.target")
                Spacer()
                localText("training.table.actual")
            }
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(TLColor.neutral500)
        }
    }

    /// 「N 組 · 強度 ×75%」這種動作級摘要；沒有課表目標（自由訓練）時不顯示。
    private var exerciseTableSummary: String? {
        guard let exerciseId = viewModel.currentExerciseId,
              let plannedCount = viewModel.blueprint?.exercises.first(where: { $0.exerciseId == exerciseId })?.setCount
        else { return nil }
        var parts = [String(localized: "training.table.setCount \(plannedCount)", bundle: .module)]
        if let pill = WeightSourceFormatting.intensityPillText(viewModel.blueprint?.intensityFactor ?? 1.0) {
            parts.append(String(format: String(localized: "training.preview.intensity %@", bundle: .module), pill))
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func setTableRow(_ row: ActiveWorkoutViewModel.SetTableRow) -> some View {
        HStack(spacing: 12) {
            setRowBadge(row)
                .frame(width: 24)
            setRowTarget(row)
                .frame(maxWidth: .infinity, alignment: .leading)
            setRowActual(row)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, row.status == .current ? 6 : 3)
        .listRowBackground(row.status == .current ? TLColor.neutral300 : nil)
        .opacity(row.status == .upcoming ? 0.6 : 1)
    }

    @ViewBuilder private func setRowBadge(_ row: ActiveWorkoutViewModel.SetTableRow) -> some View {
        switch row.status {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .current:
            ZStack {
                Circle().fill(TLColor.accent800)
                Text(verbatim: "\(row.setIndex + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(TLColor.bg)
            }
            .frame(width: 20, height: 20)
        case .upcoming:
            Text(verbatim: "\(row.setIndex + 1)")
                .font(.caption)
                .foregroundStyle(TLColor.neutral500)
        }
    }

    private func setRowTarget(_ row: ActiveWorkoutViewModel.SetTableRow) -> some View {
        let text: String
        if let weight = row.target?.targetWeight {
            let reps = row.target?.targetReps.map { " × \($0)" } ?? ""
            text = "\(WeightDisplay.weight(weight))\(reps)"
        } else if let reps = row.target?.targetReps {
            text = "× \(reps)"
        } else {
            text = "—"
        }
        return HStack(spacing: 0) {
            // 已完成的組沿用既有「第N組」文案，但不視覺化顯示（11c 的表格不畫這行）——
            // 純粹讓大量既有 UITest（斷言完成後看得到「第N組」）繼續能找到這個節點，換掉字面
            // 顯示（改成打勾圖示）但保留可被 accessibility 找到的節點，避免一次弄壞一堆測試。
            if row.status == .done {
                localText("training.setIndex \(row.setIndex + 1)")
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(false)
            }
            Text(verbatim: text)
                .monospacedDigit()
                .fontWeight(row.status == .current ? .bold : .regular)
                .foregroundStyle(row.status == .current ? TLColor.accent800 : TLColor.neutral600)
        }
    }

    @ViewBuilder private func setRowActual(_ row: ActiveWorkoutViewModel.SetTableRow) -> some View {
        switch row.status {
        case .done:
            HStack(spacing: 4) {
                if let actual = row.actual {
                    // 重量／次數是數值資料（verbatim）；「×」不用翻譯，寫死字面量會被 SwiftUI 當
                    // LocalizedStringKey 隱式抽進 String Catalog，故明確 verbatim（見 History 同類註解）。
                    Text(verbatim: "\(WeightDisplay.weight(actual.weight)) × \(actual.reps)")
                        .monospacedDigit()
                        .fontWeight(.bold)
                        .foregroundStyle(actual.status == .skipped ? .secondary : .primary)
                }
                // 復原鍵貼著它要撤銷的那一組，且只有剛記錄的那組有。
                // .borderless（而非預設樣式）：預設樣式會讓整列空白處都轉發點擊，
                // 一碰列就誤撤銷——同 bug③ 的教訓。
                if let actual = row.actual, viewModel.isUndoable(setId: actual.id) {
                    Button {
                        Task { await viewModel.undoLastSet() }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(localText("training.undoLastSet"))
                    .accessibilityIdentifier("activeWorkout.undoSet")
                }
            }
        case .current:
            // 沿用既有「第N組」文案（不是 11c 原稿的「現在這組」）：這串字是「即將記錄的是第幾組」
            // 這件事唯一的可見文字來源，UITests 大量依賴它確認「有沒有真的記到下一組」，換掉會
            // 一次弄壞一堆既有測試，換來的視覺差異不值得。
            localText("training.setIndex \(row.setIndex + 1)")
                .font(.footnote)
                .foregroundStyle(TLColor.accent700)
        case .upcoming:
            Text(verbatim: "—").foregroundStyle(TLColor.neutral500)
        }
    }

    @ViewBuilder
    private func sessionStatusIcon(_ status: SessionExercise.Status) -> some View {
        switch status {
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .current:
            Image(systemName: "arrowtriangle.right.circle.fill").foregroundStyle(.tint)
        case .partial:
            Image(systemName: "circle.lefthalf.filled").foregroundStyle(.orange)
        case .upcoming:
            Image(systemName: "circle").foregroundStyle(.secondary)
        }
    }

    /// 右側進度：課表動作「已做/課表」（如 1/3）；臨場加練顯示已做組數；無則不顯示。
    private func sessionProgress(_ exercise: SessionExercise) -> String? {
        if exercise.isPlanned {
            return "\(exercise.doneSetCount)/\(exercise.plannedSetCount)"
        }
        return exercise.doneSetCount > 0 ? "\(exercise.doneSetCount)" : nil
    }

    /// 13e 中途改課選單內容：換動作／加減組／跳過／移除，都只影響今天這一場。
    /// 加減組／跳過只對課表動作（`isPlanned`）有意義；移除只在還沒開始（沒有任何記錄）時開放。
    @ViewBuilder private var midWorkoutEditMenu: some View {
        if let exercise = midWorkoutEditTarget {
            Button {
                replacingExerciseId = exercise.id
            } label: {
                localText("training.edit.replace")
            }
            if exercise.isPlanned {
                Button {
                    viewModel.addPlannedSet(for: exercise.id)
                } label: {
                    Text(verbatim: String(
                        format: String(localized: "training.edit.addSet %lld %lld", bundle: .module),
                        exercise.plannedSetCount, exercise.plannedSetCount + 1
                    ))
                }
                if exercise.plannedSetCount > exercise.doneSetCount {
                    Button {
                        viewModel.removePlannedSet(for: exercise.id)
                    } label: {
                        Text(verbatim: String(
                            format: String(localized: "training.edit.removeSet %lld %lld", bundle: .module),
                            exercise.plannedSetCount, max(exercise.doneSetCount, exercise.plannedSetCount - 1)
                        ))
                    }
                }
                Button {
                    Task { await viewModel.skipRemainingSets(for: exercise.id) }
                } label: {
                    localText("training.edit.skipExercise")
                }
            }
            if exercise.doneSetCount == 0 {
                Button(role: .destructive) {
                    viewModel.removeFromSession(exerciseId: exercise.id)
                } label: {
                    localText("training.edit.removeFromSession")
                }
            }
        }
    }

    /// 「下一組」預覽（當前 section footer）：不用翻課表就知道接下來做什麼。
    @ViewBuilder private var nextSetPreviewFooter: some View {
        switch viewModel.nextSetPreview {
        case .upcoming(let name, let target, let isNextExercise):
            let value = nextSetText(name: name, target: target, includeName: isNextExercise)
            Label {
                // value 含 DB 動作名／數值（verbatim），套進本地化前綴「下一組／接下來」
                if isNextExercise {
                    localText("training.upNext \(value)")
                } else {
                    localText("training.nextSet \(value)")
                }
            } icon: {
                Image(systemName: "arrow.turn.down.right")
            }
            .font(.footnote)
        case .lastSet:
            Label {
                localText("training.lastSet")
            } icon: {
                Image(systemName: "flag.checkered")
            }
            .font(.footnote)
        case .none:
            EmptyView()
        }
    }

    /// 組出「[動作名] 60kg × 8」；換動作時帶名稱，同動作只給重量×次數。
    private func nextSetText(name: String, target: PlannedTargetSet?, includeName: Bool) -> String {
        var parts: [String] = []
        if includeName { parts.append(name) }
        if let weight = target?.targetWeight {
            let reps = target?.targetReps.map { " × \($0)" } ?? ""
            parts.append("\(WeightDisplay.weight(weight))\(reps)")
        } else if let reps = target?.targetReps {
            parts.append("× \(reps)")
        }
        return parts.joined(separator: " ")
    }

    private var currentSetEditor: some View {
        VStack(spacing: 16) {
            inputBand
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
        .padding(.horizontal, TLSpace.page)
    }

    /// 輸入色帶（11c）：大數字＋來源標示（14c）＋快捷鍵，包在 neutral-300 底的圓角區塊裡。
    private var inputBand: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let annotation = targetAnnotationText {
                Label {
                    Text(verbatim: annotation)
                } icon: {
                    Image(systemName: "arrow.up.circle.fill")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(TLColor.accent700)
            }
            HStack(spacing: 24) {
                stepper(
                    label: "training.weight",
                    value: "\(WeightDisplay.value(viewModel.draftWeightValue)) \(viewModel.draftWeightUnit.rawValue)",
                    idPrefix: "activeWorkout.weight",
                    big: true,
                    onMinus: { viewModel.bumpWeight(-1) },
                    onPlus: { viewModel.bumpWeight(1) }
                )
                stepper(
                    label: "training.reps",
                    value: "\(viewModel.draftReps)",
                    idPrefix: "activeWorkout.reps",
                    big: true,
                    onMinus: { viewModel.bumpReps(-1) },
                    onPlus: { viewModel.bumpReps(1) }
                )
            }
            quickActionRow
        }
        .padding(TLSpace.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TLColor.neutral300)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.inner, style: .continuous))
        .padding(.horizontal, TLSpace.page)
    }

    /// 「目標 80% 1RM · 已預填」；草稿一旦偏離目標就不再顯示（不然跟實際輸入矛盾）。
    private var targetAnnotationText: String? {
        guard let target = viewModel.currentTarget, target.targetWeight != nil,
              !viewModel.isDraftModifiedFromTarget,
              let algebra = WeightSourceFormatting.algebraText(target.weightSource)
        else { return nil }
        return String(format: String(localized: "training.table.prefilledFromTarget %@", bundle: .module), algebra)
    }

    private var quickActionRow: some View {
        let step = viewModel.draftWeightUnit == .kg ? "2.5" : "5"
        return HStack(spacing: 8) {
            quickPill("−\(step)") { viewModel.bumpWeight(-1) }
            quickPill("+\(step)") { viewModel.bumpWeight(1) }
            if viewModel.currentTarget?.targetWeight != nil {
                quickPill(String(localized: "training.table.resetToTarget", bundle: .module)) {
                    viewModel.resetToTarget()
                }
            } else if !viewModel.currentBlockSets.isEmpty {
                quickPill(String(localized: "training.table.sameAsLast", bundle: .module)) {
                    viewModel.applyLastSetValues()
                }
            }
        }
    }

    private func quickPill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(TLColor.accent700)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(TLColor.bg)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private let restPresets = [30, 60, 90, 120, 150, 180, 240, 300]

    private func stepper(
        label: LocalizedStringKey,
        value: String,
        idPrefix: String,
        big: Bool = false,
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
                    .font(big ? TLFont.display(36) : .title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(TLColor.neutral900)
                    .frame(minWidth: big ? 96 : 72)
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
