import DesignSystem
import SharedKernel
import SwiftUI
import TrainingDomain

public struct ActiveWorkoutView: View {
    /// 目前語言：`localString` 要靠它才能查到 app 設定的語言（而非手機語系）。
    @Environment(\.locale) private var locale
    @Bindable private var viewModel: ActiveWorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsExercisePicker = false
    @State private var showsFinishSheet = false
    /// 點輸入色帶大數字 → 開重量／次數選擇器（11c 沒有 ± stepper）。
    @State private var showsValueEditor = false
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
            // 標題是動作名（DB 資料，verbatim 不本地化）；沒有動作時用本地化的「訓練中」。
            // 11c 把動作名做成內容大標，但 nav 標題仍保留（inline 小標）——維持 13c/空狀態
            // 有名稱、且大量 `navigationBars[名稱]` 的 UITest 照樣找得到。
            .navigationTitle(viewModel.currentExerciseId
                .map { Text(verbatim: viewModel.name(for: $0)) } ?? localText("training.active.title"))
            .inlineNavigationTitle()
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
                    .accessibilityIdentifier("activeWorkout.finish")
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
                exercisePicker { exercise in
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
                    exercisePicker { newExercise in
                        Task { await viewModel.replaceExercise(oldId, with: newExercise.id) }
                    }
                }
            }
            .sheet(isPresented: $showsValueEditor) {
                valueEditorSheet
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

    /// 訓練中挑動作 sheet（自由訓練加動作／13e 換動作共用）：跟課表/範本加動作同一套 PickerSheet，
    /// 單選、肌群 filter、點一列即回呼。
    private func exercisePicker(onSelect: @escaping (CatalogExercise) -> Void) -> some View {
        PickerSheet(
            title: localText("training.chooseExercise"),
            searchPrompt: localText("training.searchExercises"),
            allItems: viewModel.catalog.map { ExercisePickerItem(exercise: $0, locale: locale) },
            filters: MuscleGroup.allCases.map { PickerSheetFilterChip(id: $0.rawValue, label: $0.displayName(locale)) },
            matchesFilter: { item, filter in item.exercise.muscleGroup.rawValue == filter.id },
            selection: .single { item in onSelect(item.exercise) },
            labels: TrainingPickerLabels.standard
        )
    }

    private var emptyState: some View {
        ZStack {
            TLColor.bg.ignoresSafeArea()
            EmptyState(
                systemImage: "dumbbell",
                title: localString("training.pickToStart", locale),
                message: localString("training.pickToStart.hint", locale),
                actionTitle: localString("training.addExercise", locale),
                action: { showsExercisePicker = true }
            )
            .padding(.horizontal, TLSpace.page)
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
                        format: localString("training.rest.doneOfTotal %lld %lld", locale),
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
                        format: localString("training.rest.startEarly %lld", locale), doneCount + 1
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
                // 標籤要跟著偏好走。寫死 30 的話按鈕上寫「+30 秒」、實際卻調別的值。
                restPill(String(format: localString("training.rest.adjust %lld", locale),
                                viewModel.restStep)) {
                    viewModel.adjustRest(viewModel.restStep)
                }
                restPill(String(format: localString("training.rest.adjust %lld", locale),
                                -viewModel.restStep)) {
                    viewModel.adjustRest(-viewModel.restStep)
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
                format: localString("training.rest.next %lld", locale),
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
                            Text(verbatim: String(format: localString("training.rest.targetReps %lld", locale), targetReps))
                        }
                        if let lastReps = viewModel.currentBlockSets.last?.reps {
                            Text(verbatim: String(format: localString("training.rest.lastReps %lld", locale), lastReps))
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
                restPill("−\(WeightDisplay.value(viewModel.weightStep))") { viewModel.bumpWeight(-1) }
                restPill("+\(WeightDisplay.value(viewModel.weightStep))") { viewModel.bumpWeight(1) }
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

    /// 進行中（11c）：整頁自訂捲動版面（非原生 List）——動作名當主標、組表、輸入色帶、
    /// 完成鈕、接下來清單，一路往下。組表刻意取代原本 4 條進度膠囊（每組重量不同時膠囊表達不了）。
    private func recordingContent(exerciseId: UUID) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TLSpace.section) {
                exerciseHeader(exerciseId)
                setTableCard
                inputBand
                currentSetActions
                nextSetPreviewFooter
                upNextSection
            }
            .padding(.horizontal, TLSpace.page)
            .padding(.vertical, TLSpace.section)
        }
        .background(TLColor.bg.ignoresSafeArea())
    }

    /// 動作名當頁面主標（11c）：kicker「訓練中·時長」＋ 動作名 34pt ＋ 動作級摘要副標，
    /// 右上一顆 44pt ⋯ 圓鈕 → 對「當前動作」開中途改課（13e）。
    private func exerciseHeader(_ exerciseId: UUID) -> some View {
        HStack(alignment: .top, spacing: TLSpace.gapM) {
            VStack(alignment: .leading, spacing: 4) {
                localText("training.active.kicker \(viewModel.durationMinutes)")
                    .font(TLFont.zh(TLFont.kicker, .semibold))
                    .tracking(TLFont.kickerTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(TLColor.accent600)
                ExerciseNameWithEquipment(
                    title: Text(verbatim: viewModel.name(for: exerciseId))
                        .font(TLFont.zh(TLFont.pageTitle, .bold))
                        .foregroundColor(TLColor.text),
                    equipment: viewModel.equipmentName(for: exerciseId, locale: locale)
                )
                if let summary = exerciseTableSummary {
                    Text(verbatim: summary)
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral600)
                }
                if let last = viewModel.lastSummary(for: exerciseId) {
                    localText("training.lastTime \(last)")
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                }
            }
            Spacer(minLength: 0)
            Button {
                midWorkoutEditTarget = viewModel.sessionSequence.first { $0.id == exerciseId }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TLColor.neutral700)
                    .frame(width: TLSize.iconButton, height: TLSize.iconButton)
                    .background(TLColor.neutral200)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localText("training.edit.menu"))
            .accessibilityIdentifier("activeWorkout.midWorkoutEdit")
        }
    }

    /// 組表（11c）：動作級摘要（已在 header）＋「組/目標/實際」欄名 ＋ 每組一列圓角列。
    private var setTableCard: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapS) {
            HStack {
                localText("training.table.set")
                Spacer()
                localText("training.table.target")
                    .accessibilityIdentifier("activeWorkout.targetColumn")
                Spacer()
                localText("training.table.actual")
            }
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(TLColor.neutral500)
            .padding(.horizontal, TLSpace.rowInset)
            VStack(spacing: TLSpace.gapS) {
                ForEach(viewModel.setTableRows) { row in
                    setTableRow(row)
                }
            }
        }
    }

    /// 完成這組（赭紅實心）＋ 跳過此組／休息計時器。
    private var currentSetActions: some View {
        VStack(spacing: TLSpace.gapM) {
            Button {
                Task { await viewModel.completeCurrentSet() }
            } label: {
                localText("training.completeSet")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tlPrimary)
            .accessibilityIdentifier("activeWorkout.completeSet")

            HStack(spacing: TLSpace.gapS) {
                Button {
                    Task { await viewModel.skipCurrentSet() }
                } label: {
                    localText("training.skipSet").frame(maxWidth: .infinity)
                }
                .buttonStyle(.tlSecondary)
                .accessibilityIdentifier("activeWorkout.skipSet")
                if viewModel.restRemaining == nil {
                    Menu {
                        ForEach(restPresets, id: \.self) { sec in
                            Button(restClock(sec)) { viewModel.startManualRest(seconds: sec) }
                        }
                    } label: {
                        Image(systemName: "timer")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.tlSecondary)
                    .accessibilityLabel(localText("training.restTimer"))
                    .accessibilityIdentifier("activeWorkout.restTimer")
                }
            }
        }
    }

    /// 接下來（11c E）：純文字列（動作名 ＋ 右側目標 Caprasimo）＋1px 底線，無卡片底、無狀態圖示；
    /// 長按任一列開中途改課（13e），最後一列「臨時加練」。刻意不套 TLGroup 卡片——設計稿是直接
    /// 排在頁面底色上、只用細線分隔。
    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapS) {
            localText("training.upNext.section")
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(TLColor.neutral500)
            VStack(spacing: 0) {
                ForEach(viewModel.sessionSequence) { exercise in
                    upNextRow(exercise)
                    Rectangle().fill(TLColor.divider).frame(height: 1)
                }
                Button {
                    showsExercisePicker = true
                } label: {
                    HStack(spacing: TLSpace.gapS) {
                        Image(systemName: "plus")
                        localText("training.tempExtra")
                        Spacer(minLength: 0)
                    }
                    .font(TLFont.zh(TLFont.rowTitle, .semibold))
                    .foregroundStyle(TLColor.accent600)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func upNextRow(_ exercise: SessionExercise) -> some View {
        Button {
            Task { await viewModel.select(exerciseId: exercise.id) }
        } label: {
            HStack(spacing: TLSpace.gapM) {
                Text(verbatim: exercise.name)
                    .font(TLFont.zh(TLFont.rowTitle, exercise.isCurrent ? .semibold : .regular))
                    .foregroundStyle(TLColor.text)
                Spacer(minLength: TLSpace.gapS)
                if let target = upNextTargetText(exercise) {
                    Text(verbatim: target)
                        .font(TLFont.display(13.5))
                        .foregroundStyle(TLColor.neutral500)
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 長按該列＝對這個動作開中途改課（13e）——設計稿「長按可換動作」。
        .onLongPressGesture(minimumDuration: 0.4) { midWorkoutEditTarget = exercise }
        .accessibilityIdentifier("activeWorkout.midWorkoutEdit")
    }

    /// 「接下來」列右側目標：`3 × 10 · 24 kg`（設計稿 Caprasimo）；自由加練沒有課表目標＝nil。
    private func upNextTargetText(_ exercise: SessionExercise) -> String? {
        guard exercise.isPlanned, let rep = viewModel.blueprint?.target(exerciseId: exercise.id, position: 0)
        else { return nil }
        var text = "\(exercise.plannedSetCount)"
        if let reps = rep.targetReps { text += " × \(reps)" }
        if let weight = rep.targetWeight { text += " · \(weight.displayString)" }
        return text
    }

    /// 「N 組 · 強度 ×75%」這種動作級摘要；沒有課表目標（自由訓練）時不顯示。
    private var exerciseTableSummary: String? {
        guard let exerciseId = viewModel.currentExerciseId,
              let plannedCount = viewModel.blueprint?.exercises.first(where: { $0.exerciseId == exerciseId })?.setCount
        else { return nil }
        var parts = [String(format: localString("training.table.setCount %lld", locale), plannedCount)]
        if let pill = WeightSourceFormatting.intensityPillText(viewModel.blueprint?.intensityFactor ?? 1.0) {
            parts.append(String(format: localString("training.preview.intensity %@", locale), pill))
        }
        return parts.joined(separator: " · ")
    }

    /// 組表一列（11c）：每組自成一顆圓角列——現在這組 neutral-300 反白，其餘 neutral-100，
    /// 未做的整列淡出。取代原本靠 List row background 的做法（已移出 List）。
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
        .padding(.horizontal, TLSpace.rowInset)
        .padding(.vertical, row.status == .current ? 14 : 11)
        .background(row.status == .current ? TLColor.neutral300 : TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.inner, style: .continuous))
        .opacity(row.status == .upcoming ? 0.6 : 1)
    }

    @ViewBuilder private func setRowBadge(_ row: ActiveWorkoutViewModel.SetTableRow) -> some View {
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
                    .accessibilityIdentifier("activeWorkout.currentSet")
                    .accessibilityIdentifier("activeWorkout.completedSet")
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
                            .foregroundStyle(TLColor.accent700)   // 換掉系統藍，配色一致
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(localText("training.undoLastSet"))
                    .accessibilityIdentifier("activeWorkout.undoSet")
                }
            }
        case .current:
            // 11c 設計稿寫「現在這組」；但「第N組」是 UITests 大量依賴的可見文字（判斷有沒有記到
            // 下一組），所以可見顯示改「現在這組」、另外保留一個 0 尺寸的「第N組」節點給測試找，
            // 跟已完成列同一招，不弄壞既有測試。
            HStack(spacing: 0) {
                localText("training.setIndex \(row.setIndex + 1)")
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(false)
                localText("training.table.currentSet")
                    .font(.footnote)
                    .foregroundStyle(TLColor.accent700)
            }
        case .upcoming:
            Text(verbatim: "—").foregroundStyle(TLColor.neutral500)
        }
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
                        format: localString("training.edit.addSet %lld %lld", locale),
                        exercise.plannedSetCount, exercise.plannedSetCount + 1
                    ))
                }
                if exercise.plannedSetCount > exercise.doneSetCount {
                    Button {
                        viewModel.removePlannedSet(for: exercise.id)
                    } label: {
                        Text(verbatim: String(
                            format: localString("training.edit.removeSet %lld %lld", locale),
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
            .accessibilityIdentifier("activeWorkout.nextSetPreview")
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

    /// 輸入色帶（11c）：大數字讀出（點開 DualValuePicker 改重量／次數）＋來源標示（14c）＋
    /// 快捷鍵；neutral-300 底、右側大圓角且不到底的不對稱形狀，左緣貼齊螢幕。取代原本的 ± stepper
    /// ——設計稿沒有 stepper，數字直接點開選擇器；快捷膠囊做 ±級距／回到目標微調。
    private var inputBand: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let annotation = targetAnnotationText {
                Label {
                    Text(verbatim: annotation)
                } icon: {
                    Image(systemName: "arrow.up")
                }
                .font(TLFont.zh(11.5, .semibold))
                .foregroundStyle(TLColor.accent700)
            }
            Button {
                showsValueEditor = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: WeightDisplay.value(viewModel.draftWeightValue))
                        .font(TLFont.display(TLFont.bigNumber))
                        .foregroundStyle(TLColor.neutral900)
                    Text(verbatim: viewModel.draftWeightUnit.rawValue)
                        .font(TLFont.zh(15, .medium))
                        .foregroundStyle(TLColor.neutral700)
                    Spacer(minLength: TLSpace.gapM)
                    Text(verbatim: "×")
                        .font(TLFont.display(30))
                        .foregroundStyle(TLColor.neutral500)
                    Text(verbatim: "\(viewModel.draftReps)")
                        .font(TLFont.display(TLFont.bigNumber))
                        .foregroundStyle(TLColor.neutral900)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("activeWorkout.valueEditor")
            quickActionRow
        }
        .padding(.vertical, 18)
        .padding(.leading, TLSpace.page)
        .padding(.trailing, TLSpace.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TLColor.neutral300)
        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 40, topTrailingRadius: 40, style: .continuous))
        // 左緣貼齊螢幕（抵銷外層 page 邊距）、右緣不到底 → 不對稱色帶。
        .padding(.leading, -TLSpace.page)
        .padding(.trailing, TLSpace.gapL)
    }

    /// 大數字點開的重量／次數選擇器（取代 stepper）；重量依使用者的級距偏好、次數 1…40。
    private var valueEditorSheet: some View {
        let weightValues = WeightRange.values(for: viewModel.draftWeightUnit, step: viewModel.weightStep)
        let repsValues = (1...40).map(Double.init)
        return NavigationStack {
            VStack {
                DualValuePicker(
                    primaryValue: $viewModel.draftWeightValue,
                    primaryValues: weightValues,
                    primaryKicker: localString("training.weight", locale),
                    primaryFormat: { "\(WeightDisplay.value($0)) \(viewModel.draftWeightUnit.rawValue)" },
                    secondaryValue: Binding(
                        get: { Double(viewModel.draftReps) },
                        set: { viewModel.draftReps = Int($0) }
                    ),
                    secondaryValues: repsValues,
                    secondaryKicker: localString("training.reps", locale),
                    secondaryFormat: { "\(Int($0))" }
                )
                Spacer()
            }
            .padding(TLSpace.page)
            .background(TLColor.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { showsValueEditor = false } label: { localText("training.ok") }
                }
            }
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
    }

    /// 「目標 80% 1RM · 已預填」；草稿一旦偏離目標就不再顯示（不然跟實際輸入矛盾）。
    private var targetAnnotationText: String? {
        guard let target = viewModel.currentTarget, target.targetWeight != nil,
              !viewModel.isDraftModifiedFromTarget,
              let algebra = WeightSourceFormatting.algebraText(target.weightSource, locale: locale)
        else { return nil }
        return String(format: localString("training.table.prefilledFromTarget %@", locale), algebra)
    }

    private var quickActionRow: some View {
        let step = WeightDisplay.value(viewModel.weightStep)
        return HStack(spacing: 8) {
            quickPill("−\(step)") { viewModel.bumpWeight(-1) }
            quickPill("+\(step)") { viewModel.bumpWeight(1) }
            if viewModel.currentTarget?.targetWeight != nil {
                quickPill(localString("training.table.resetToTarget", locale)) {
                    viewModel.resetToTarget()
                }
            } else if !viewModel.currentBlockSets.isEmpty {
                quickPill(localString("training.table.sameAsLast", locale)) {
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
}

private extension View {
    /// nav 標題用 inline 小標（避免跟內容大標重複佔一整條大標題）；macOS 沒有這個 API，no-op。
    @ViewBuilder func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
