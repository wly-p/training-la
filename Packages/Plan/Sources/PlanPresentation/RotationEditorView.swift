import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI
import UniformTypeIdentifiers

/// 循環課表編輯（設計稿 12a）：套 `EditScaffold`，跟 9b 完全同骨架，只有列內容不同——
/// 這裡的列是「範本 ＋ 序號圓章 ＋ 右側組數」，不是動作。**沒有**總長度、沒有休息列、沒有日期。
/// 新增內容只有一個路徑：從範本庫多選匯入（copy 快照），不再支援現場拼一個新 workout。
/// 直接吃 `Rotation` 物件（跟 `TemplateFormView` 同precedent）：清單已經載入過，不用再依 id 非同步查一次
/// （避開 drill-in 陷阱那整類問題，見 memory `nav-drill-in-pitfall`）。
public struct RotationEditorView: View {
    public enum Target {
        case create
        case edit(Rotation)
    }

    let target: Target
    let templates: [WorkoutTemplate]
    /// 使用者的重量級距偏好；強度倍率預覽要跟投影收斂算出同一個數字。
    let weightStep: Double
    let name: (UUID) -> String
    let onSubmit: (String, [WorkoutSpec], Bool, Int, Double) async -> Void
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftName: String
    @State private var draftWorkouts: [WorkoutSpec]
    @State private var draftIntensityFactor: Double
    @State private var pickingTemplates = false
    @State private var selectedTemplateIds: Set<UUID> = []
    @State private var isActiveOnCreate = true
    @State private var startAtDay = 1
    @State private var showStartDayEditor = false
    @State private var showDeleteConfirm = false
    /// 14b：正在編輯覆寫值的那一格（nil＝沒有 sheet 開著）。
    @State private var overridingWorkoutId: UUID?

    private let initialName: String
    private let initialWorkouts: [WorkoutSpec]
    private let initialIntensityFactor: Double

    public init(
        target: Target,
        templates: [WorkoutTemplate],
        weightStep: Double,
        name: @escaping (UUID) -> String,
        onSubmit: @escaping (String, [WorkoutSpec], Bool, Int, Double) async -> Void,
        onDelete: @escaping () async -> Void = {}
    ) {
        self.target = target
        self.templates = templates
        self.weightStep = weightStep
        self.name = name
        self.onSubmit = onSubmit
        self.onDelete = onDelete
        switch target {
        case .create:
            initialName = ""
            initialWorkouts = []
            initialIntensityFactor = 1.0
        case .edit(let rotation):
            initialName = rotation.name
            initialWorkouts = rotation.workouts
            initialIntensityFactor = rotation.intensityFactor
        }
        _draftName = State(initialValue: initialName)
        _draftWorkouts = State(initialValue: initialWorkouts)
        _draftIntensityFactor = State(initialValue: initialIntensityFactor)
    }

    private var isCreating: Bool {
        if case .create = target { true } else { false }
    }

    private var canSave: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draftWorkouts.isEmpty
            && (isCreating || draftName != initialName || draftWorkouts != initialWorkouts
                || draftIntensityFactor != initialIntensityFactor)
    }

    /// 最近用過的範本（依 `updatedAt` 新到舊，取前 5）：picker 的「最近用過」分組。
    private var recentTemplateIds: [UUID] {
        templates.sorted { $0.updatedAt > $1.updatedAt }.prefix(5).map(\.id)
    }

    public var body: some View {
        EditScaffold(
            title: $draftName,
            titlePrompt: localText("rotation.name.placeholder"),
            canSave: canSave,
            cancelLabel: localText("plan.cancel"),
            saveLabel: localText("plan.save"),
            onCancel: { dismiss() },
            onSave: {
                Task {
                    await onSubmit(draftName, draftWorkouts, isActiveOnCreate, startAtDay - 1, draftIntensityFactor)
                    dismiss()
                }
            }
        ) {
            statsLine
            workoutsSection
            hintLine
            intensitySection
            if isCreating {
                createdAfterSection
            } else {
                deleteSection
            }
        }
        .sheet(isPresented: $pickingTemplates) {
            PickerSheet(
                title: Text(verbatim: String(localized: "rotation.picker.title", bundle: .module)),
                searchPrompt: localText("rotation.picker.searchPrompt"),
                allItems: templates.map { TemplatePickerItem(template: $0, name: name) },
                recentItemIds: recentTemplateIds,
                selection: .multiple(
                    selectedIds: $selectedTemplateIds,
                    confirmLabel: { count in localText("rotation.picker.addCount \(count)") },
                    onConfirm: importSelectedTemplates
                ),
                labels: PlanPickerLabels.standard
            )
        }
        .sheet(isPresented: Binding(
            get: { overridingWorkoutId != nil },
            set: { if !$0 { overridingWorkoutId = nil } }
        )) {
            if let id = overridingWorkoutId {
                intensityOverrideSheet(for: id)
            }
        }
        .tlConfirmationDialog(
            isPresented: $showDeleteConfirm,
            title: localText("rotation.delete.confirm.title"),
            message: localText("rotation.delete.confirm.message"),
            confirmLabel: localText("plan.delete"),
            cancelLabel: localText("plan.cancel"),
            role: .destructive,
            confirmIdentifier: "confirmDeleteRotationFromEditor",
            onConfirm: {
                Task {
                    await onDelete()
                    dismiss()
                }
            }
        )
    }

    // MARK: - 統計

    private var totalSets: Int { draftWorkouts.reduce(0) { $0 + $1.sets.count } }

    private var estimatedMinutesPerRound: Int {
        let restTotal = draftWorkouts.flatMap(\.sets).reduce(0) { $0 + ($1.restSec ?? 60) }
        let workTotal = totalSets * 40
        return max(1, Int((Double(restTotal + workTotal) / 60).rounded()))
    }

    private var statsLine: some View {
        (localText("rotation.stats.cycle \(draftWorkouts.count)")
            + Text(verbatim: " · ")
            + localText("rotation.stats.setsPerRound \(totalSets)")
            + Text(verbatim: " · ")
            + localText("rotation.stats.minutes \(estimatedMinutesPerRound)"))
            .font(TLFont.zh(TLFont.rowSub, .semibold))
            .foregroundStyle(TLColor.neutral500)
    }

    // MARK: - 範本順序

    private var workoutsSection: some View {
        EditSection(localText("rotation.workouts.section")) {
            TLGroup {
                ForEach(Array(draftWorkouts.enumerated()), id: \.element.id) { index, spec in
                    row(index, spec)
                }
                addRow
            }
        }
    }

    private func row(_ index: Int, _ spec: WorkoutSpec) -> some View {
        ListRow(
            title: Text(verbatim: spec.name),
            subtitle: Text(PlanFormatting.exerciseNamesSummary(spec, name: name)),
            leading: {
                HStack(spacing: 8) {
                    dragHandle
                    CircleBadge(fill: TLColor.accent200) {
                        Text(verbatim: "\(index + 1)")
                            .font(TLFont.display(15))
                            .foregroundStyle(TLColor.accent800)
                    }
                }
            },
            trailing: {
                HStack(spacing: 8) {
                    RowValue("\(spec.sets.count)", unit: String(localized: "rotation.setsUnit", bundle: .module))
                    // 14b：這一格的強度覆寫（未覆寫＝線框「基準」，已覆寫＝accent 實心 ×N%）。
                    IntensityOverridePill(
                        factor: spec.intensityFactor,
                        baselineLabel: String(localized: "rotation.intensity.baseline", bundle: .module),
                        onTap: { overridingWorkoutId = spec.id }
                    )
                }
            }
        )
        .draggable(RotationWorkoutTransfer(workoutId: spec.id))
        .dropDestination(for: RotationWorkoutTransfer.self) { items, _ in
            guard let dragged = items.first else { return false }
            moveWorkout(fromId: dragged.workoutId, toId: spec.id)
            return true
        }
        .contextMenu {
            Button {
                moveWorkout(index, direction: -1)
            } label: {
                Label { localText("rotation.reorder.up") } icon: { Image(systemName: "arrow.up") }
            }
            .disabled(index == 0)
            Button {
                moveWorkout(index, direction: 1)
            } label: {
                Label { localText("rotation.reorder.down") } icon: { Image(systemName: "arrow.down") }
            }
            .disabled(index == draftWorkouts.count - 1)
            Button(role: .destructive) {
                draftWorkouts.remove(at: index)
            } label: {
                Label { localText("rotation.reorder.remove") } icon: { Image(systemName: "trash") }
            }
        }
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(TLColor.neutral400)
    }

    private var addRow: some View {
        ListRow(
            title: localText("rotation.addTemplate"),
            onTap: { pickingTemplates = true },
            leading: { CircleBadge(icon: "plus", fill: TLColor.neutral200, tint: TLColor.neutral600) }
        )
    }

    private var hintLine: some View {
        localText("rotation.hint")
            .font(TLFont.zh(TLFont.rowSub, .regular))
            .foregroundStyle(TLColor.neutral500)
            .padding(.horizontal, TLSpace.rowInset)
    }

    // MARK: - 強度基準（14b）

    /// 「套用後」試算：拿目前循環裡的第一個範本、它的第一組當代表動作。
    /// 只給百分比沒人算得出槓上要放幾片，這是這個群組存在的理由（03-schedule.md B 節）。
    private var intensityPreviewLines: [IntensityFactorGroup.PreviewLine] {
        guard let firstSet = draftWorkouts.first?.sets.first else { return [] }
        // 帶著單位一起算：使用者可能用 lb，寫死 kg 會標錯。
        let baseWeight = firstSet.targetWeight?.resolvedWeight ?? Weight(value: 60, unit: .kg)
        let base = baseWeight.value
        // 跟投影收斂用同一個取整（WeightRange.steppedDown），否則預覽與實際排出來的數字會兜不攏。
        let result = WeightRange.steppedDown(base * draftIntensityFactor, step: weightStep)
        return [
            IntensityFactorGroup.PreviewLine(
                label: Text(verbatim: "\(name(firstSet.exerciseId)) ")
                    + localText("template.setNumber \(firstSet.setIndex + 1)"),
                expression: Text(verbatim: String(
                    format: "%@ × %.0f%%", baseWeight.displayString, draftIntensityFactor * 100
                )),
                result: Text(verbatim: Weight(value: result, unit: baseWeight.unit).displayString)
            )
        ]
    }

    private var intensitySection: some View {
        EditSection(localText("rotation.intensity.section"), footer: localText("rotation.intensity.footer")) {
            IntensityFactorGroup(
                factor: $draftIntensityFactor,
                customLabel: String(localized: "rotation.intensity.custom", bundle: .module),
                previewLines: intensityPreviewLines
            )
        }
    }

    /// 點某一格的強度膠囊：ValuePicker 選 0.5–1.2，或「使用基準」清掉覆寫。
    /// 「取消」不寫回——覆寫值只在按「完成」時才真的存進 `draftWorkouts`。
    private func intensityOverrideSheet(for workoutId: UUID) -> some View {
        let baseline = draftIntensityFactor
        let current = draftWorkouts.first { $0.id == workoutId }?.intensityFactor
        return IntensityOverrideSheet(
            baseline: baseline,
            current: current,
            onCancel: { overridingWorkoutId = nil },
            onUseBaseline: {
                if let index = draftWorkouts.firstIndex(where: { $0.id == workoutId }) {
                    draftWorkouts[index].intensityFactor = nil
                }
                overridingWorkoutId = nil
            },
            onCommit: { newValue in
                if let index = draftWorkouts.firstIndex(where: { $0.id == workoutId }) {
                    draftWorkouts[index].intensityFactor = newValue
                }
                overridingWorkoutId = nil
            }
        )
    }

    // MARK: - 建立後（僅新增模式）

    private var createdAfterSection: some View {
        EditSection(localText("rotation.createdAfter.section"), footer: localText("rotation.createdAfter.footer")) {
            TLGroup {
                ListRow(
                    title: localText("rotation.createdAfter.activateNow"),
                    trailing: {
                        Toggle("", isOn: $isActiveOnCreate).labelsHidden().toggleStyle(.tlSwitch)
                    }
                )
                ListRow(
                    title: localText("rotation.createdAfter.startDay"),
                    onTap: { showStartDayEditor.toggle() },
                    trailing: { RowValue("\(startAtDay)") }
                )
            }
            if showStartDayEditor {
                Stepper(value: $startAtDay, in: 1...max(1, draftWorkouts.count)) {
                    HStack {
                        localText("rotation.createdAfter.startDay")
                        Spacer()
                        Text(verbatim: "\(startAtDay)").foregroundStyle(TLColor.neutral600)
                    }
                }
                .padding(.horizontal, TLSpace.rowInset)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - 刪除（僅編輯模式）

    private var deleteSection: some View {
        TLGroup {
            SettingsRow(
                localText("rotation.delete.thisRotation"),
                role: .destructive,
                onTap: { showDeleteConfirm = true }
            )
        }
        .accessibilityIdentifier("deleteRotationButton")
    }

    // MARK: - 匯入／排序

    private func importSelectedTemplates() {
        let selected = templates.filter { selectedTemplateIds.contains($0.id) }
        let imported = selected.map { template in
            WorkoutSpec(
                name: template.name,
                sets: template.sets.map { set in
                    PlanSet(
                        id: UUID(), exerciseId: set.exerciseId, exerciseIndex: set.exerciseIndex,
                        setIndex: set.setIndex, targetWeight: set.targetWeight, targetReps: set.targetReps,
                        restSec: set.restSec
                    )
                }
            )
        }
        draftWorkouts.append(contentsOf: imported)
        selectedTemplateIds = []
    }

    private func moveWorkout(_ index: Int, direction: Int) {
        let target = index + direction
        guard draftWorkouts.indices.contains(index), draftWorkouts.indices.contains(target) else { return }
        draftWorkouts.swapAt(index, target)
    }

    private func moveWorkout(fromId: UUID, toId: UUID) {
        guard fromId != toId,
              let fromIndex = draftWorkouts.firstIndex(where: { $0.id == fromId }),
              let toIndex = draftWorkouts.firstIndex(where: { $0.id == toId })
        else { return }
        let moved = draftWorkouts.remove(at: fromIndex)
        draftWorkouts.insert(moved, at: toIndex)
    }
}

/// 循環範本順序拖曳排序用的傳輸值。
private struct RotationWorkoutTransfer: Codable, Transferable {
    let workoutId: UUID
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

/// 14b 週期格子的強度覆寫編輯 sheet：循環（12a）與長期（9c）共用，故不是 `private`
/// （同一個 PlanPresentation module 內共用，不用為兩個呼叫端拉出去 DesignSystem）。
/// 「取消」不寫回；「使用基準」清掉覆寫（nil）；「完成」把 ValuePicker 選的值寫回。
struct IntensityOverrideSheet: View {
    let baseline: Double
    let current: Double?
    let onCancel: () -> Void
    let onUseBaseline: () -> Void
    let onCommit: (Double) -> Void

    @State private var value: Double

    init(baseline: Double, current: Double?, onCancel: @escaping () -> Void, onUseBaseline: @escaping () -> Void, onCommit: @escaping (Double) -> Void) {
        self.baseline = baseline
        self.current = current
        self.onCancel = onCancel
        self.onUseBaseline = onUseBaseline
        self.onCommit = onCommit
        _value = State(initialValue: current ?? baseline)
    }

    private var values: [Double] { stride(from: 50, through: 120, by: 5).map { Double($0) / 100 } }

    var body: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapL) {
            HStack {
                Button(action: onCancel) { localText("plan.cancel") }
                    .font(TLFont.zh(15.5, .medium))
                    .foregroundStyle(TLColor.neutral600)
                Spacer()
                Button(action: onUseBaseline) { localText("rotation.intensity.useBaseline") }
                    .font(TLFont.zh(TLFont.rowSub, .semibold))
                    .foregroundStyle(TLColor.neutral600)
                Spacer()
                Button { onCommit(value) } label: { localText("plan.done") }
                    .font(TLFont.zh(15.5, .bold))
                    .foregroundStyle(TLColor.accent700)
            }
            ValuePicker(
                value: $value,
                values: values,
                kicker: String(localized: "rotation.intensity.custom", bundle: .module),
                format: { String(format: "%.0f%%", $0 * 100) },
                quickActions: [
                    .init("-5%") { value = max(values.first ?? 0.5, value - 0.05) },
                    .init("+5%") { value = min(values.last ?? 1.2, value + 0.05) },
                ]
            )
        }
        .padding(TLSpace.page)
        .padding(.top, TLSpace.gapL)
        .background(TLColor.bg.ignoresSafeArea())
        .presentationDetents([.height(360)])
    }
}
