import DesignControls
import DesignSystem
import SharedKernel
import SwiftUI
import TrainingDomain
#if os(iOS)
import UIKit
#endif

public struct ActiveWorkoutView: View {
    /// 目前語言：`localString` 要靠它才能查到 app 設定的語言（而非手機語系）。
    @Environment(\.locale) private var locale
    /// 重量顯示單位（根部注入，見 SharedKernel/WeightDisplayUnit）。
    @Environment(\.weightDisplayUnit) private var weightUnit
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
                // 切回前景：補算剩餘秒數並重啟 ticking；離開前景：停掉 ticking，
                // 避免回前景時補跑「到點前景提醒」與背景已投遞的通知重複。
                // `.background` 與 `.inactive` 要分開傳：只有前者會真的被系統通知提醒過。
                if phase == .active {
                    viewModel.enterForeground()
                } else {
                    viewModel.suspendRestTicking(toBackground: phase == .background)
                }
                // 螢幕常亮只在前景維持：進背景要還原，否則這個旗標會洩漏到 App 之外。
                keepScreenAwake(phase == .active)
            }
            // 訓練中不要讓螢幕自己鎖掉：休息 90 秒、螢幕 30 秒關掉，做完一組手是濕的
            // 還要先解鎖才能記錄。離開畫面（結束／放棄／離開三條路徑都會走到 onDisappear）還原。
            .onAppear { keepScreenAwake(true) }
            .onDisappear { keepScreenAwake(false) }
            .alert(localText("training.restOver"), isPresented: Binding(
                get: { viewModel.showsRestEndedAlert },
                set: { if !$0 { viewModel.dismissRest() } }
            )) {
                Button { viewModel.dismissRest() } label: { localText("training.startNextSet") }
                    .accessibilityIdentifier("activeWorkout.restEnded.next")
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
            // `?? ""` 會讓那個空字串變成可翻譯字面量，被抽進 String Catalog
            // 變成一個永遠不會被翻譯的空 key（體檢 E11）。改成條件式。
            if let message = viewModel.errorMessage { Text(message) }
        }
    }


    /// 16b：「還想練就加一組，不然往下一個動作走。」／16e：整場摘要一行（完整數據在 13a）。
    private var completeBandMessage: String {
        guard viewModel.isPlanFullyDone else {
            return localString("training.done.exercise.message", locale)
        }
        let stats = viewModel.sessionStats
        return String(
            format: localString("training.done.plan.message %lld %lld %@", locale),
            stats.exerciseCount, stats.setCount, WeightDisplay.volume(stats.volume, in: weightUnit)
        )
    }

    /// 「下一個 · 臥推 →」／「結束訓練 →」。動作名是 DB 資料，套進本地化模板。
    private var completePrimaryTitle: String {
        guard !viewModel.isPlanFullyDone else {
            return localString("training.done.finish", locale)
        }
        return String(
            format: localString("training.done.next %@", locale), viewModel.nextPlannedName ?? ""
        )
    }

    /// 訓練中挑動作 sheet（自由訓練加動作／13e 換動作共用）：跟課表/範本加動作同一套 TLPickerSheet，
    /// 單選、肌群 filter、點一列即回呼。
    private func exercisePicker(onSelect: @escaping (CatalogExercise) -> Void) -> some View {
        TLPickerSheet(
            title: localText("training.chooseExercise"),
            searchPrompt: localText("training.searchExercises"),
            allItems: viewModel.catalog.map { ExercisePickerItem(exercise: $0, locale: locale) },
            filters: MuscleGroup.allCases.map { TLPickerSheetFilterChip(id: $0.rawValue, label: $0.displayName(locale)) },
            matchesFilter: { item, filter in item.exercise.muscleGroup.rawValue == filter.id },
            selection: .single { item in onSelect(item.exercise) },
            labels: TrainingPickerLabels.standard
        )
    }

    private var emptyState: some View {
        ZStack {
            TLColor.bg.ignoresSafeArea()
            TLEmptyState(
                systemImage: "dumbbell",
                title: localString("training.pickToStart", locale),
                message: localString("training.pickToStart.hint", locale),
                actionTitle: localString("training.addExercise", locale),
                actionIdentifier: "activeWorkout.addExercise",
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
            VStack(alignment: .leading, spacing: TLSpace.gapL) {
                // 動作名已經是 navigationTitle（native 大標題），這裡不重複，只加課表進度 kicker。
                if let plannedCount = viewModel.blueprint?.exercises.first(where: { $0.exerciseId == exerciseId })?.setCount {
                    Text(verbatim: String(
                        format: localString("training.rest.doneOfTotal %lld %lld", locale),
                        doneCount, plannedCount
                    ))
                    .font(TLFont.zh(TLFont.buttonLabelSmall, .semibold))
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
        return TLCard(fill: TLColor.accent200) {
            VStack(spacing: TLSpace.cardSectionGap) {
                localText("training.resting")
                    .accessibilityIdentifier("activeWorkout.resting")
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
                    .font(TLFont.zh(TLFont.badgeText))
                    .foregroundStyle(TLColor.accent700)
                HStack(spacing: TLSpace.sectionHeaderGap) {
                    // 標籤要跟著偏好走。寫死 30 的話按鈕上寫「+30 秒」、實際卻調別的值。
                    TLPillButton(
                        Text(verbatim: String(format: localString("training.rest.adjust %lld", locale),
                                              viewModel.restStep)),
                        tint: TLColor.accent800, width: .fill
                    ) { viewModel.adjustRest(viewModel.restStep) }
                    TLPillButton(
                        Text(verbatim: String(format: localString("training.rest.adjust %lld", locale),
                                              -viewModel.restStep)),
                        tint: TLColor.accent800, width: .fill
                    ) { viewModel.adjustRest(-viewModel.restStep) }
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
            .frame(maxWidth: .infinity)
        }
    }

    /// 進度條：剩餘 / 這段休息的起始總長，隨時間往 1 走（1＝快結束）。
    private var restProgress: Double {
        guard let remaining = viewModel.restRemaining, let total = viewModel.restTotalSeconds, total > 0 else { return 1 }
        return 1 - (Double(remaining) / Double(total))
    }

    /// 「接下來·第N組」卡：休息中提早看到、也能先調——目標次數/上一組實際次數/重量，
    /// 重量沿用 draftWeightValue（appendSet 後 prefillDraft 已經預填好下一組的值）。
    private var nextSetCard: some View {
        TLCard {
            VStack(alignment: .leading, spacing: TLSpace.sectionHeaderGap) {
                Text(verbatim: String(
                    format: localString("training.rest.next %lld", locale),
                    viewModel.currentBlockSets.count + 1
                ))
                .font(TLFont.zh(TLFont.badgeText))
                .foregroundStyle(TLColor.neutral500)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: TLSpace.valueUnitGap) {
                        if let exerciseId = viewModel.currentExerciseId {
                            Text(verbatim: viewModel.name(for: exerciseId))
                                .font(TLFont.zh(TLFont.emptyTitle, .semibold))
                        }
                        HStack(spacing: TLSpace.labelGap) {
                            if let targetReps = viewModel.currentTarget?.targetReps {
                                Text(verbatim: String(format: localString("training.rest.targetReps %lld", locale), targetReps))
                            }
                            if let lastReps = viewModel.currentBlockSets.last?.measurement.displayReps {
                                Text(verbatim: String(format: localString("training.rest.lastReps %lld", locale), lastReps))
                            }
                        }
                        .font(TLFont.zh(TLFont.caption))
                        .foregroundStyle(TLColor.neutral600)
                    }
                    Spacer()
                    Text(verbatim: "\(WeightDisplay.value(viewModel.draftWeightValue)) \(viewModel.draftWeightUnit.rawValue)")
                        .font(TLFont.display(28))
                        .foregroundStyle(TLColor.text)
                }
                HStack(spacing: TLSpace.gapS) {
                    TLPillButton(Text(verbatim: "−\(WeightDisplay.value(viewModel.weightStep))"),
                                 tint: TLColor.accent800, width: .fill) { viewModel.bumpWeight(-1) }
                    TLPillButton(Text(verbatim: "+\(WeightDisplay.value(viewModel.weightStep))"),
                                 tint: TLColor.accent800, width: .fill) { viewModel.bumpWeight(1) }
                }
                localText("training.rest.tapHint")
                    .font(TLFont.zh(TLFont.rowSub))
                    .foregroundStyle(TLColor.neutral500)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                // 完成區與輸入色帶是同一個容器的兩種狀態，不是新畫面：crossfade 切換，
                // 不做位移或彈跳，組表才不會在眼前跳掉（16b 實作備註）。
                if viewModel.showExerciseComplete {
                    ExerciseCompleteBand(
                        isPlanFullyDone: viewModel.isPlanFullyDone,
                        title: viewModel.isPlanFullyDone
                            ? localText("training.done.plan.title")
                            : localText("training.done.exercise.title"),
                        message: completeBandMessage,
                        primaryTitle: completePrimaryTitle,
                        oneMoreSetLabel: localText("training.done.oneMoreSet"),
                        addExtraLabel: localText("training.done.addExtra"),
                        onOneMoreSet: { viewModel.continueSameExercise() },
                        onAddExtra: { showsExercisePicker = true },
                        onPrimary: {
                            if viewModel.isPlanFullyDone {
                                viewModel.dismissExerciseComplete()
                                showsFinishSheet = true
                            } else {
                                Task { await viewModel.advanceToNextPlanned() }
                            }
                        }
                    )
                        .transition(.opacity)
                } else {
                    inputBand
                        .transition(.opacity)
                    currentSetActions
                    nextSetPreviewFooter
                }
                upNextSection
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.showExerciseComplete)
            .padding(.horizontal, TLSpace.page)
            .padding(.vertical, TLSpace.section)
        }
        .background(TLColor.bg.ignoresSafeArea())
    }

    /// 動作名當頁面主標（11c）：kicker「訓練中·時長」＋ 動作名 34pt ＋ 動作級摘要副標，
    /// 右上一顆 44pt ⋯ 圓鈕 → 對「當前動作」開中途改課（13e）。
    private func exerciseHeader(_ exerciseId: UUID) -> some View {
        HStack(alignment: .top, spacing: TLSpace.gapM) {
            VStack(alignment: .leading, spacing: TLSpace.valueUnitGap) {
                // 完成狀態換一句 kicker 並轉綠：狀態的改變寫在標題列，不另外開一塊宣告。
                (viewModel.showExerciseComplete
                    ? localText("training.done.kicker \(viewModel.durationMinutes)")
                    : localText("training.active.kicker \(viewModel.durationMinutes)"))
                    .font(TLFont.zh(TLFont.kicker, .semibold))
                    .tracking(TLFont.kickerTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(viewModel.showExerciseComplete ? TLColor.sage700 : TLColor.accent600)
                TLTitleWithTag(
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
                if let last = viewModel.lastSummary(for: exerciseId, in: weightUnit) {
                    localText("training.lastTime \(last)")
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                }
            }
            Spacer(minLength: 0)
            TLCircleIconButton(systemImage: "ellipsis", style: .neutral) {
                midWorkoutEditTarget = viewModel.sessionSequence.first { $0.id == exerciseId }
            }
            .accessibilityLabel(localText("training.edit.menu"))
            .accessibilityIdentifier("activeWorkout.midWorkoutEdit")
        }
    }


    /// 組表（11c）：動作級摘要（已在 header）＋「組/目標/實際」欄名 ＋ 每組一列圓角列。
    private var setTableCard: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapS) {
            SetTableColumns {
                localText("training.table.set")
            } target: {
                localText("training.table.target")
                    .accessibilityIdentifier("activeWorkout.targetColumn")
            } actual: {
                localText("training.table.actual")
                    .accessibilityIdentifier("activeWorkout.actualColumn")
            }
            .font(TLFont.zh(TLFont.kicker, .semibold))
            .textCase(.uppercase)
            .foregroundStyle(TLColor.neutral500)
            .padding(.horizontal, TLSpace.rowInset)
            VStack(spacing: TLSpace.gapS) {
                ForEach(viewModel.setTableRows) { row in
                    SetTableRow(
                        row: row,
                        weightUnit: weightUnit,
                        isUndoable: row.actual.map { viewModel.isUndoable(setId: $0.id) } ?? false,
                        currentSetLabel: localText("training.table.currentSet"),
                        undoLabel: localText("training.undoLastSet"),
                        onUndo: { Task { await viewModel.undoLastSet() } }
                    )
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
                    UpNextRow(
                        name: exercise.name,
                        isCurrent: exercise.isCurrent,
                        target: upNextTargetText(exercise),
                        onSelect: { Task { await viewModel.select(exerciseId: exercise.id) } },
                        onLongPress: { midWorkoutEditTarget = exercise }
                    )
                    Rectangle().fill(TLColor.divider).frame(height: TLSize.hairline)
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
                    .padding(.vertical, TLSpace.fieldPadV)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }


    /// 「接下來」列右側目標：`3 × 10 · 24 kg`（設計稿 Caprasimo）；自由加練沒有課表目標＝nil。
    private func upNextTargetText(_ exercise: SessionExercise) -> String? {
        guard exercise.isPlanned, let rep = viewModel.blueprint?.target(exerciseId: exercise.id, position: 0)
        else { return nil }
        var text = "\(exercise.plannedSetCount)"
        if let reps = rep.targetReps { text += " × \(reps)" }
        if let weight = rep.targetWeight { text += " · \(weight.displayString(in: weightUnit))" }
        return text
    }

    /// 「N 組 · 強度 ×75%」這種動作級摘要；沒有課表目標（自由訓練）時不顯示。
    /// 動作做完後換成成績：「3 組 · 22.5 kg · 總量 540 kg」（16b）／最後一個動作寫
    /// 「本場最後一個動作」取代總量（16e）——那句話取代了舊實作底部那條重複的提示。
    private var exerciseTableSummary: String? {
        if viewModel.showExerciseComplete { return completedExerciseSummary }
        guard let exerciseId = viewModel.currentExerciseId,
              let plannedCount = viewModel.blueprint?.exercises.first(where: { $0.exerciseId == exerciseId })?.setCount
        else { return nil }
        var parts = [String(format: localString("training.table.setCount %lld", locale), plannedCount)]
        if let pill = WeightSourceFormatting.intensityPillText(viewModel.blueprint?.intensityFactor ?? 1.0) {
            parts.append(String(format: localString("training.preview.intensity %@", locale), pill))
        }
        return parts.joined(separator: " · ")
    }

    private var completedExerciseSummary: String {
        let stats = viewModel.completedExerciseStats
        var parts = [String(format: localString("training.table.setCount %lld", locale), stats.setCount)]
        if let heaviest = stats.heaviest {
            parts.append(WeightDisplay.weight(heaviest, in: weightUnit))
        }
        parts.append(viewModel.isPlanFullyDone
            ? localString("training.done.lastExercise", locale)
            : String(format: localString("training.done.volume %@", locale),
                     WeightDisplay.volume(stats.volume, in: weightUnit)))
        return parts.joined(separator: " · ")
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
                    Task { await viewModel.removeFromSession(exerciseId: exercise.id) }
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
            .font(TLFont.zh(TLFont.caption))
            .accessibilityIdentifier("activeWorkout.nextSetPreview")
        // 「本場最後一組，做完就結束」拿掉：做完之後完成區的副行已經寫「本場最後一個動作」，
        // 同一件事講兩次（01-training C1 把它列為舊實作的問題之一）。
        case .lastSet, .none:
            EmptyView()
        }
    }

    /// 組出「[動作名] 60kg × 8」；換動作時帶名稱，同動作只給重量×次數。
    private func nextSetText(name: String, target: PlannedTargetSet?, includeName: Bool) -> String {
        var parts: [String] = []
        if includeName { parts.append(name) }
        if let weight = target?.targetWeight {
            let reps = target?.targetReps.map { " × \($0)" } ?? ""
            parts.append("\(WeightDisplay.weight(weight, in: weightUnit))\(reps)")
        } else if let reps = target?.targetReps {
            parts.append("× \(reps)")
        }
        return parts.joined(separator: " ")
    }

    /// 輸入色帶（11c）：大數字讀出（點開 TLDualValuePicker 改重量／次數）＋來源標示（14c）＋
    /// 快捷鍵；neutral-300 底、右側大圓角且不到底的不對稱形狀，左緣貼齊螢幕。取代原本的 ± stepper
    /// ——設計稿沒有 stepper，數字直接點開選擇器；快捷膠囊做 ±級距／回到目標微調。
    private var inputBand: some View {
        VStack(alignment: .leading, spacing: TLSpace.bandGap) {
            if let annotation = targetAnnotationText {
                Label {
                    Text(verbatim: annotation)
                } icon: {
                    Image(systemName: "arrow.up")
                }
                .font(TLFont.zh(TLFont.rowSub, .semibold))
                .foregroundStyle(TLColor.accent700)
            }
            Button {
                showsValueEditor = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: TLSpace.labelGap) {
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
        .padding(.vertical, TLSpace.rowInset)
        .padding(.leading, TLSpace.page)
        .padding(.trailing, TLSpace.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TLColor.neutral300)
        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: TLRadius.band, topTrailingRadius: TLRadius.band, style: .continuous))
        // 左緣貼齊螢幕（抵銷外層 page 邊距）、右緣不到底 → 不對稱色帶。
        .padding(.leading, -TLSpace.page)
        .padding(.trailing, TLSpace.gapL)
    }

    /// 大數字點開的重量／次數選擇器（取代 stepper）；重量依使用者的級距偏好、次數 1…40。
    ///
    /// 外框用 `TLCompactSheet`：高度跟著內容量測，不再寫死 —— 之前寫死 260 讓滾輪被壓扁，
    /// 而且「好」是 NavigationStack 的 toolbar，浮在標題列上蓋到下面的欄名。
    private var valueEditorSheet: some View {
        let weightValues = WeightRange.values(for: viewModel.draftWeightUnit, step: viewModel.weightStep)
        let repsValues = (1...40).map(Double.init)
        return TLCompactSheet(
            title: Text(verbatim: viewModel.currentExerciseId.map { viewModel.name(for: $0) } ?? ""),
            confirmTitle: localText("training.ok"),
            onConfirm: { showsValueEditor = false }
        ) {
            TLDualValuePicker(
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
        }
    }

    /// 「目標 80% 1RM · 已預填」；草稿一旦偏離目標就不再顯示（不然跟實際輸入矛盾）。
    private var targetAnnotationText: String? {
        guard let target = viewModel.currentTarget, target.targetWeight != nil,
              !viewModel.isDraftModifiedFromTarget,
              let algebra = WeightSourceFormatting.algebraText(target.weightSource, locale: locale, in: weightUnit)
        else { return nil }
        return String(format: localString("training.table.prefilledFromTarget %@", locale), algebra)
    }

    private var quickActionRow: some View {
        let step = WeightDisplay.value(viewModel.weightStep)
        return HStack(spacing: TLSpace.gapS) {
            TLPillButton(Text(verbatim: "−\(step)")) { viewModel.bumpWeight(-1) }
            TLPillButton(Text(verbatim: "+\(step)")) { viewModel.bumpWeight(1) }
            if viewModel.currentTarget?.targetWeight != nil {
                TLPillButton(localText("training.table.resetToTarget")) {
                    viewModel.resetToTarget()
                }
            } else if !viewModel.currentBlockSets.isEmpty {
                TLPillButton(localText("training.table.sameAsLast")) {
                    viewModel.applyLastSetValues()
                }
            }
        }
    }

    private let restPresets = [30, 60, 90, 120, 150, 180, 240, 300]
}

/// 停用／還原螢幕自動鎖定。macOS 沒有 idle timer 這個概念，整個是 no-op。
///
/// 刻意做成自由函式而不是 View modifier：它動的是 App 層級的全域旗標，
/// 不屬於任何一棵 view 樹，包成 modifier 只會讓「誰負責還原」更難看清楚。
@MainActor
private func keepScreenAwake(_ enabled: Bool) {
    #if os(iOS)
    UIApplication.shared.isIdleTimerDisabled = enabled
    #endif
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
