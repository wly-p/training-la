import DesignSystem
import SharedKernel
import SwiftUI
import TrainingDomain

/// 完成摘要（13a）：練了多久、做了多少、有沒有達標——只回答這三件事，不做慶祝動畫頁。
struct FinishWorkoutSheet: View {
    /// 目前語言：`localString` 要靠它才能查到 app 設定的語言（而非手機語系）。
    @Environment(\.locale) private var locale
    let workout: Workout
    let workoutName: String?
    let exerciseName: (UUID) -> String
    let detectPersonalRecords: () async -> [ExercisePRAnnouncement]
    let onFinish: (Int?, String) async -> Void
    let onDiscard: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var feeling: Int?
    @State private var note = ""
    @State private var showsNoteField = false
    @State private var personalRecords: [ExercisePRAnnouncement] = []
    @State private var showsDiscardConfirm = false

    private var exerciseSummaries: [FinishSummaryFormatting.ExerciseSummary] {
        FinishSummaryFormatting.exerciseSummaries(workout.blocks, nameLookup: exerciseName)
    }

    private var achievedCount: (achieved: Int, total: Int) {
        FinishSummaryFormatting.achievedSetCount(workout.sets)
    }

    private var totals: SessionTotals { FinishSummaryFormatting.totals(workout.sets) }
    private var totalVolume: Double { totals.volumeKilograms }

    /// 非重量模式的分項（時間／距離／純次數）。各模式各自累計、不互相換算——
    /// 「撐 90 秒」跟「推 100 公斤」之間沒有大小關係，湊成一個數字只會是假的總量。
    ///
    /// **排版與樣式屬於 B2-ui 那張設計票**，這裡只是最小呈現，讓數字不至於算完就沒人看得到。
    /// 現階段沒有 B2-ui 就建立不了非重量模式的動作，所以這一行實際上不會出現。
    private var otherWorkText: String? {
        guard totals.hasNonWeightWork else { return nil }
        var parts: [String] = []
        if totals.durationSeconds > 0 { parts.append("\(totals.durationSeconds / 60) min") }
        if totals.distanceMeters > 0 { parts.append("\(WeightDisplay.value(totals.distanceMeters / 1000)) km") }
        if totals.repsOnly > 0 { parts.append("\(totals.repsOnly) reps") }
        return parts.joined(separator: " · ")
    }
    private var targetVolume: Double { FinishSummaryFormatting.targetVolume(workout.sets) }

    private var durationMinutes: Int {
        guard let start = workout.startedAt else { return 0 }
        return max(0, Int(Date().timeIntervalSince(start) / 60))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TLSpace.section) {
                    header
                    statsCard
                    if let pr = personalRecords.first {
                        prBanner(pr)
                    }
                    exerciseList
                    feelingSection
                    if showsNoteField {
                        TextField(text: $note, prompt: localText("training.notes.placeholder"), axis: .vertical) { Text(verbatim: "") }
                            .padding(TLSpace.rowInset)
                            .background(TLColor.neutral100)
                            .clipShape(RoundedRectangle(cornerRadius: TLRadius.inner, style: .continuous))
                    }
                    Button {
                        // 不自己 dismiss()：外層 ActiveWorkoutView 監聽 viewModel.isDismissed
                        // 變化後會 dismiss 自己（連同這個 nested sheet 一起關閉）。若這裡也搶著
                        // dismiss 一次，兩層 sheet 幾乎同時關閉會讓其中一層的關閉動畫卡住、
                        // 殘留在畫面上擋住底下的 TabView（跟 13c 的 alert race 是同一類問題）。
                        // 存檔失敗時 isDismissed 不會變 true，sheet 也就正確地留著讓使用者看到錯誤。
                        Task {
                            await onFinish(feeling, note)
                        }
                    } label: {
                        localText("training.finish.saveAndFinish")
                            .accessibilityIdentifier("finishSheet.save")
                    }
                    .buttonStyle(.tlPrimary)

                    Button(role: .destructive) {
                        showsDiscardConfirm = true
                    } label: {
                        localText("training.finish.discard")
                    }
                    .buttonStyle(.tlDestructiveText)
                    .frame(maxWidth: .infinity)
                }
                .padding(TLSpace.page)
                .padding(.bottom, 20)
            }
            .background(TLColor.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("training.keepGoing") }
                }
            }
            .task {
                personalRecords = await detectPersonalRecords()
            }
            .confirmationDialog(
                localText("training.finish.discardConfirmTitle"),
                isPresented: $showsDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    // 同上——不自己 dismiss()，交給外層監聽 isDismissed 統一處理。
                    Task {
                        await onDiscard()
                    }
                } label: {
                    localText("training.finish.discardConfirm")
                }
            }
        }
    }

    // MARK: - 標頭：狀態(kicker)／名詞(主標)／時間(副行)，不要合成一句。

    private var header: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapS) {
            localText("training.finish.title")
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(TLColor.accent700)
            Text(verbatim: workoutName ?? localString("training.free", locale))
                .font(TLFont.zh(30, .bold))
                .foregroundStyle(TLColor.text)
            Text(verbatim: subtitleTimeRange)
                .font(.footnote)
                .foregroundStyle(TLColor.neutral600)
        }
    }

    private var subtitleTimeRange: String {
        guard let start = workout.startedAt else { return "" }
        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.dateFormat = "HH:mm"
        // Calendar.current 讀裝置語系，不是 app 的語言設定——星期縮寫要走帶 locale 的 formatter。
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = locale
        let weekday = weekdayFormatter.shortWeekdaySymbols[workout.day.weekdayNumber - 1]
        return "\(workout.day.month)/\(workout.day.day)（\(weekday)） · \(timeFormatter.string(from: start))–\(timeFormatter.string(from: Date()))"
    }

    // MARK: - 數字卡

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                statNumber(String(durationMinutes), label: "training.finish.minutes", alignment: .leading)
                Spacer()
                statNumber(WeightDisplay.value(totalVolume), label: "training.finish.totalVolume", alignment: .center)
                Spacer()
                achievedStat
            }
            if let otherWorkText {
                Text(verbatim: String(format: localString("training.finish.otherWork %@", locale), otherWorkText))
                    .font(TLFont.zh(12.5, .regular))
                    .foregroundStyle(TLColor.neutral600)
            }
            if targetVolume > 0 {
                // 6pt 圓角進度條（neutral-200 軌 ＋ 赭紅填），取代偏細的原生 ProgressView。
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(TLColor.neutral200)
                        Capsule().fill(TLColor.accent)
                            .frame(width: geo.size.width * min(totalVolume / targetVolume, 1))
                    }
                }
                .frame(height: 6)
                Text(verbatim: String(
                    format: localString("training.finish.volumeGoal %@ %@", locale),
                    WeightDisplay.value(targetVolume), String(format: "%.0f%%", totalVolume / targetVolume * 100)
                ))
                .font(.footnote)
                .foregroundStyle(TLColor.neutral600)
            }
        }
        .padding(TLSpace.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TLColor.neutral300)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }

    private func statNumber(
        _ value: String, label: String, alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(verbatim: value)
                .font(TLFont.display(34))
                .foregroundStyle(TLColor.text)
            Text(LocalizedStringKey(label), bundle: .module)
                .font(.caption2)
                .foregroundStyle(TLColor.neutral600)
        }
    }

    /// 達標組數：分子 34pt、分母縮小（`12/13` 的 `/13`），對齊右欄。
    private var achievedStat: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(verbatim: "\(achievedCount.achieved)")
                    .font(TLFont.display(34))
                Text(verbatim: "/\(achievedCount.total)")
                    .font(TLFont.display(20))
                    .foregroundStyle(TLColor.neutral500)
            }
            .foregroundStyle(TLColor.text)
            Text("training.finish.achievedSets", bundle: .module)
                .font(.caption2)
                .foregroundStyle(TLColor.neutral600)
        }
    }

    // MARK: - PR 條：全 App 唯一「值得高興」的訊號，沒有就整條不出現，不寫「今天沒有新紀錄」。

    private func prBanner(_ pr: ExercisePRAnnouncement) -> some View {
        let name = exerciseName(pr.exerciseId)
        // 重量模式的三種文案沿用既有 key；時間／距離／純次數的文案排版屬於 B2-ui 那張設計票，
        // 現階段建立不了那種動作所以走不到，先用同一組 key 的最小填法，別讓它變成死路。
        let weightText = pr.measurement.displayWeight.map(WeightDisplay.weight) ?? ""
        let reps = pr.measurement.displayReps ?? 0
        let text: String
        switch pr.kind {
        case .newRepsAtWeight:
            text = String(format: localString("training.finish.pr.newReps %@ %@ %lld", locale), name, weightText, reps)
        case .newWeightAtReps, .newDuration, .newDistance, .newReps:
            text = String(format: localString("training.finish.pr.newWeight %@ %@ %lld", locale), name, weightText, reps)
        case .firstEver:
            // 第一次練這個動作：說「創新高」很怪（沒有舊紀錄可破），改寫成「第一筆紀錄」。
            text = String(format: localString("training.finish.pr.firstEver %@ %@ %lld", locale), name, weightText, reps)
        }
        return Label {
            Text(verbatim: text)
        } icon: {
            Image(systemName: "trophy.fill")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(TLColor.sage800)
        .padding(TLSpace.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TLColor.sage200)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.inner, style: .continuous))
    }

    // MARK: - 這場做了什麼

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapS) {
            localText("training.finish.whatYouDid")
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(TLColor.neutral500)
            TLGroup {
                ForEach(exerciseSummaries) { summary in
                    HStack(spacing: TLSpace.gapM) {
                        Text(verbatim: summary.name)
                            .font(TLFont.zh(TLFont.rowTitle, .semibold))
                            .foregroundStyle(TLColor.text)
                        Spacer(minLength: TLSpace.gapS)
                        // 組數·重量放右側（Caprasimo 數字），貼著達標勾號——不再當名稱下的副標。
                        Text(verbatim: String(
                            format: localString("training.finish.exerciseSets %lld %@", locale),
                            summary.setCount, summary.weightRange
                        ))
                        .font(TLFont.display(15))
                        .foregroundStyle(TLColor.neutral600)
                        achievementBadge(summary.allAchieved)
                    }
                    .padding(.horizontal, TLSpace.rowInset)
                    .padding(.vertical, 14)
                }
            }
        }
    }

    @ViewBuilder private func achievementBadge(_ allAchieved: Bool?) -> some View {
        switch allAchieved {
        case true:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(TLColor.sage700)
        case false:
            Image(systemName: "circle").foregroundStyle(TLColor.neutral400)
        case nil:
            EmptyView()
        }
    }

    // MARK: - 感覺如何（選填）

    private var feelingSection: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapS) {
            localText("training.howFeel")
                .font(.footnote)
                .foregroundStyle(TLColor.neutral500)
            HStack(spacing: 8) {
                feelingChip(value: 1, label: "training.finish.feeling.easy")
                feelingChip(value: 3, label: "training.finish.feeling.justRight")
                feelingChip(value: 5, label: "training.finish.feeling.hard")
                SelectableChip(
                    localString("training.finish.addNote", locale),
                    isSelected: showsNoteField,
                    selectedFill: TLColor.accent, selectedText: TLColor.bg,
                    onTap: { showsNoteField.toggle() }
                )
            }
        }
    }

    private func feelingChip(value: Int, label: String) -> some View {
        SelectableChip(
            localString(label, locale),
            isSelected: feeling == value,
            selectedFill: TLColor.accent, selectedText: TLColor.bg,
            onTap: { feeling = feeling == value ? nil : value }
        )
        .accessibilityIdentifier("finishSheet.feeling.\(value)")
    }
}
