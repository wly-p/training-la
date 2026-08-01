import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

/// 當日排課表單（課表「+」→ 空白建立／點未完成排課編輯）。套動作庫同一套新版元件：
/// `EditScaffold` ＋ `PickerSheet` ＋ `TLGroup`/`ListRow`；逐動作用 `DraftEditSheet`（`DualValuePicker`）
/// 編組數／重量／次數／休息。`readOnly`（已完成排課）時走精簡的唯讀畫面、不可編輯。
///
/// 資料模型維持 `ExerciseTargetDraft`（每個動作統一的 組數×重量×次數＋休息，非逐組），
/// 只換視覺、不改行為。
struct PlanWorkoutFormView: View {
    /// 目前語言：`localString` 要靠它才能查到 app 設定的語言（而非手機語系）。
    @Environment(\.locale) private var locale
    let target: PlanFormTarget
    let catalog: [PlanCatalogExercise]
    /// 使用者的重量級距偏好（見 `TrainingPreferenceStoring`）。原本依器材猜（`Equipment.weightStep`），
    /// 但那是對典型健身房的假設而不是使用者的真實器材，已改成一律由設定決定。
    let weightStep: Double
    let recentExerciseIds: [UUID]
    let readOnly: Bool
    let onSubmit: (String?, DayDate, [ExerciseTargetDraft]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var date: Date
    @State private var drafts: [ExerciseTargetDraft]
    @State private var pickingExercise = false
    @State private var selectedExerciseIds: Set<UUID> = []
    @State private var editingDraftId: UUID?

    init(
        target: PlanFormTarget,
        catalog: [PlanCatalogExercise],
        weightStep: Double,
        recentExerciseIds: [UUID] = [],
        readOnly: Bool = false,
        onSubmit: @escaping (String?, DayDate, [ExerciseTargetDraft]) async -> Void
    ) {
        self.target = target
        self.catalog = catalog
        self.weightStep = weightStep
        self.recentExerciseIds = recentExerciseIds
        self.readOnly = readOnly
        self.onSubmit = onSubmit
        switch target {
        case .create(let day):
            _name = State(initialValue: "")
            _date = State(initialValue: day.asDate)
            _drafts = State(initialValue: [])
        case .edit(let plan):
            _name = State(initialValue: plan.name ?? "")
            _date = State(initialValue: plan.date.asDate)
            _drafts = State(initialValue: draftsFromBlocks(plan.blocks))
        }
    }

    private var canSave: Bool { !drafts.isEmpty }

    var body: some View {
        Group {
            if readOnly {
                readOnlyView
            } else {
                editView
            }
        }
        .sheet(isPresented: $pickingExercise) {
            PickerSheet(
                title: localText("plan.addExercise"),
                searchPrompt: localText("plan.searchExercises"),
                allItems: catalog.map { ExercisePickerItem(exercise: $0, locale: locale) },
                recentItemIds: recentExerciseIds,
                filters: MuscleGroup.allCases.map { PickerSheetFilterChip(id: $0.rawValue, label: $0.displayName(locale)) },
                matchesFilter: { item, filter in item.exercise.muscleGroup.rawValue == filter.id },
                selection: .multiple(
                    selectedIds: $selectedExerciseIds,
                    confirmLabel: { count in localText("template.picker.addCount \(count)") },
                    onConfirm: addSelectedExercises
                ),
                labels: PlanPickerLabels.standard
            )
        }
        .sheet(item: editingDraftBinding) { draft in
            if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
                DraftEditSheet(
                    exerciseName: name(for: draft.exerciseId),
                    weightStep: weightStep,
                    setCount: $drafts[index].setCount,
                    targetWeight: $drafts[index].targetWeight,
                    targetReps: $drafts[index].targetReps,
                    restSec: $drafts[index].restSec
                )
            }
        }
    }

    // MARK: - 編輯（新增/編輯）

    private var editView: some View {
        EditScaffold(
            title: $name,
            titlePrompt: localText("plan.name.placeholder"),
            canSave: canSave,
            cancelLabel: localText("plan.cancel"),
            saveLabel: localText("plan.save"),
            onCancel: { dismiss() },
            onSave: {
                Task {
                    await onSubmit(name.isEmpty ? nil : name, DayDate(date), drafts)
                    dismiss()
                }
            }
        ) {
            dateSection
            exercisesSection
        }
    }

    private var dateSection: some View {
        EditSection(localText("plan.date")) {
            TLGroup {
                HStack {
                    localText("plan.date")
                        .font(TLFont.zh(TLFont.rowTitle))
                        .foregroundStyle(TLColor.text)
                    Spacer()
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .tint(TLColor.accent)
                }
                .padding(.horizontal, TLSpace.rowInset)
                .frame(minHeight: TLSize.row)
            }
        }
    }

    private var exercisesSection: some View {
        EditSection(localText("plan.exercises")) {
            TLGroup {
                ForEach(drafts) { draft in
                    draftRow(draft)
                }
                ListRow(
                    title: localText("plan.addExercise"),
                    onTap: { pickingExercise = true },
                    leading: { CircleBadge(icon: "plus", fill: TLColor.neutral200, tint: TLColor.neutral600) }
                )
            }
        }
    }

    private func draftRow(_ draft: ExerciseTargetDraft) -> some View {
        ListRow(
            title: Text(verbatim: name(for: draft.exerciseId)),
            subtitle: Text(verbatim: summary(for: draft)),
            equipment: equipmentName(for: draft.exerciseId),
            onTap: { editingDraftId = draft.id },
            trailing: {
                Text(verbatim: capsuleText(for: draft))
                    .font(TLFont.display(15))
                    .foregroundStyle(TLColor.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(TLColor.neutral200))
            }
        )
        .contextMenu {
            let index = drafts.firstIndex { $0.id == draft.id } ?? 0
            Button {
                move(index, direction: -1)
            } label: {
                Label { localText("template.reorder.up") } icon: { Image(systemName: "arrow.up") }
            }
            .disabled(index == 0)
            Button {
                move(index, direction: 1)
            } label: {
                Label { localText("template.reorder.down") } icon: { Image(systemName: "arrow.down") }
            }
            .disabled(index == drafts.count - 1)
            Button(role: .destructive) {
                drafts.removeAll { $0.id == draft.id }
            } label: {
                Label { localText("template.reorder.remove") } icon: { Image(systemName: "trash") }
            }
        }
    }

    // MARK: - 唯讀（已完成排課）

    private var readOnlyView: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    localText("plan.close")
                        .font(TLFont.zh(15.5, .medium))
                        .foregroundStyle(TLColor.neutral600)
                }
                Spacer()
            }
            .padding(.horizontal, TLSpace.page)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: TLSpace.section) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: name.isEmpty ? localString("plan.view", locale) : name)
                            .font(TLFont.zh(TLFont.pageTitle, .bold))
                            .foregroundStyle(TLColor.text)
                        Label { localText("plan.readOnly.hint") } icon: { Image(systemName: "checkmark.circle.fill") }
                            .font(TLFont.zh(TLFont.rowSub, .regular))
                            .foregroundStyle(TLColor.neutral500)
                    }
                    EditSection(localText("plan.exercises")) {
                        TLGroup {
                            ForEach(drafts) { draft in
                                ListRow(
                                    title: Text(verbatim: name(for: draft.exerciseId)),
                                    subtitle: Text(verbatim: summary(for: draft)),
                                    trailing: {
                                        Text(verbatim: capsuleText(for: draft))
                                            .font(TLFont.display(15))
                                            .foregroundStyle(TLColor.text)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(TLColor.neutral200))
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, TLSpace.page)
                .padding(.top, TLSpace.gapL)
                .padding(.bottom, 40)
            }
        }
        .background(TLColor.bg.ignoresSafeArea())
    }

    // MARK: - 草稿操作

    private var editingDraftBinding: Binding<ExerciseTargetDraft?> {
        Binding(
            get: { drafts.first { $0.id == editingDraftId } },
            set: { if $0 == nil { editingDraftId = nil } }
        )
    }

    private func addSelectedExercises() {
        for exercise in catalog where selectedExerciseIds.contains(exercise.id) {
            // 休息預設不設（nil）——沿用舊「空白」表單行為；要休息由使用者在編輯 sheet 自己加。
            drafts.append(ExerciseTargetDraft(
                exerciseId: exercise.id,
                setCount: 3,
                targetWeight: Weight(value: 20, unit: .kg),
                targetReps: 8
            ))
        }
        selectedExerciseIds = []
    }

    private func move(_ index: Int, direction: Int) {
        let target = index + direction
        guard drafts.indices.contains(index), drafts.indices.contains(target) else { return }
        drafts.swapAt(index, target)
    }

    // MARK: - 顯示輔助

    private func name(for id: UUID) -> String {
        // 查不到＝該動作已被刪；正常流程進不來（刪除前有 ExerciseUsageChecker 擋）。
        // 用中性符號而非任何語言的字，這裡拿不到 locale。
        catalog.first { $0.id == id }?.name ?? "—"
    }

    /// 副標：組數＋休息，如「3 組 · 休息 60 秒」。
    /// 器材顯示名（動作名允許重複，靠它分辨）。
    private func equipmentName(for id: UUID) -> String {
        (catalog.first { $0.id == id }?.equipment ?? .other).displayName(locale)
    }

    private func summary(for draft: ExerciseTargetDraft) -> String {
        var text = String(format: localString("template.stats.sets %lld", locale), draft.setCount)
        if let rest = draft.restSec, rest > 0 {
            text += " · " + String(format: localString("plan.restSeconds %lld", locale), rest)
        }
        return text
    }

    /// 右側膠囊統一成「重量單位 × 次數」（例「20kg × 8」），跟範本編輯同一個格式。
    /// 走 `Weight.displayString` 而不是自己拼——那份格式化會把浮點雜訊去掉。
    private func capsuleText(for draft: ExerciseTargetDraft) -> String {
        let reps = draft.targetReps ?? 0
        if let weight = draft.targetWeight {
            return "\(weight.displayString) × \(reps)"
        }
        return "× \(reps)"
    }
}

private func formatNumber(_ v: Double) -> String {
    v == v.rounded() ? String(Int(v)) : String(v)
}

/// 單一動作草稿的編輯 sheet：組數（stepper）＋重量×次數（`DualValuePicker`）＋休息（stepper）。
/// 對齊動作庫 `SetEditSheet` 的視覺與互動。
private struct DraftEditSheet: View {
    /// 目前語言：`localString` 要靠它才能查到 app 設定的語言（而非手機語系）。
    @Environment(\.locale) private var locale
    let exerciseName: String
    let weightStep: Double
    @Binding var setCount: Int
    @Binding var targetWeight: Weight?
    @Binding var targetReps: Int?
    @Binding var restSec: Int?

    @Environment(\.dismiss) private var dismiss
    @State private var weightValue: Double
    @State private var repsValue: Double
    @State private var sets: Int
    @State private var rest: Int

    init(
        exerciseName: String,
        weightStep: Double,
        setCount: Binding<Int>,
        targetWeight: Binding<Weight?>,
        targetReps: Binding<Int?>,
        restSec: Binding<Int?>
    ) {
        self.exerciseName = exerciseName
        self.weightStep = weightStep
        self._setCount = setCount
        self._targetWeight = targetWeight
        self._targetReps = targetReps
        self._restSec = restSec
        _weightValue = State(initialValue: targetWeight.wrappedValue?.value ?? 20)
        _repsValue = State(initialValue: Double(targetReps.wrappedValue ?? 8))
        _sets = State(initialValue: setCount.wrappedValue)
        _rest = State(initialValue: restSec.wrappedValue ?? 0)
    }

    /// 這筆目標重量的單位；還沒有值時預設公斤。
    private var weightUnit: WeightUnit { targetWeight?.unit ?? .kg }

    private var weightValues: [Double] { WeightRange.values(for: weightUnit, step: weightStep) }
    private var repsValues: [Double] { Array(stride(from: 1, through: 30, by: 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapL) {
            topBar
            TLGroup {
                stepperRow(localText("plan.setCount \(sets)"), value: $sets, range: 1...20)
                    .accessibilityIdentifier("draftSetCountStepper")
                stepperRow(restLabel, value: $rest, range: 0...600, step: 15)
                    .accessibilityIdentifier("draftRestStepper")
            }
            DualValuePicker(
                primaryValue: $weightValue,
                primaryValues: weightValues,
                primaryKicker: localString("plan.weight", locale),
                secondaryValue: $repsValue,
                secondaryValues: repsValues,
                secondaryKicker: localString("plan.reps", locale),
                quickActions: [
                    .init("-\(formatNumber(weightStep))") {
                        weightValue = WeightRange.clamped(weightValue - weightStep, unit: weightUnit)
                    },
                    .init("+\(formatNumber(weightStep))") {
                        weightValue = WeightRange.clamped(weightValue + weightStep, unit: weightUnit)
                    },
                ]
            )
            Spacer(minLength: 0)
        }
        .padding(TLSpace.page)
        .padding(.top, TLSpace.gapL)
        .background(TLColor.bg.ignoresSafeArea())
        .presentationDetents([.height(520)])
    }

    private var restLabel: Text {
        rest > 0 ? localText("plan.restSeconds \(rest)") : localText("plan.restNone")
    }

    private func stepperRow(_ label: Text, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1) -> some View {
        Stepper(value: value, in: range, step: step) {
            label
                .font(TLFont.zh(TLFont.rowTitle))
                .foregroundStyle(TLColor.text)
        }
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: TLSize.row)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: { localText("plan.cancel") }
                .font(TLFont.zh(15.5, .medium))
                .foregroundStyle(TLColor.neutral600)
            Spacer()
            Text(verbatim: exerciseName)
                .font(TLFont.zh(TLFont.rowTitle, .semibold))
                .foregroundStyle(TLColor.text)
            Spacer()
            Button {
                setCount = sets
                targetWeight = Weight(value: weightValue, unit: targetWeight?.unit ?? .kg)
                targetReps = Int(repsValue)
                restSec = rest > 0 ? rest : nil
                dismiss()
            } label: {
                localText("plan.done")
            }
            .font(TLFont.zh(15.5, .bold))
            .foregroundStyle(TLColor.accent700)
        }
    }
}
