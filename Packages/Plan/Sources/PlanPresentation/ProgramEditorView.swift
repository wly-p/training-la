import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

/// 長期課表編輯（設計稿 9c/12b）：套 `EditScaffold`。每天指派一個範本或「休息」——透過共用
/// `PickerSheet` 單選，不再是自由拼裝內容（`WorkoutSpecFormView` 已移除）。
/// 直接吃 `Program` 物件（同 `RotationEditorView`/`TemplateFormView` precedent），不用 id 非同步查。
///
/// **新增模式的三態**（12b，僅 `.create` 才有）：格子分「已指派」／「已設休息」／「未指派」——
/// 後者是使用者還沒決定過的格，跟「休息」不同，用虛線圈標示；下一個要填的格會反白指路；
/// 存檔前必須全部決定過（`還有 N 格未指派 · 填完才能儲存`）。編輯既有課表沒有這個狀態——
/// 已存過的資料，缺席一律視為「休息」（沿用 9c 原本語意），不會出現虛線格。
public struct ProgramEditorView: View {
    public enum Target {
        case create
        case edit(Program)
    }

    let target: Target
    let templates: [WorkoutTemplate]
    /// 使用者的重量級距偏好；強度倍率預覽要跟投影收斂算出同一個數字。
    let weightStep: Double
    let name: (UUID) -> String
    let onSubmit: (String, Int, [Int: WorkoutSpec], Double) async -> Void
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftName: String
    @State private var draftCycleLength: Int
    @State private var draftDays: [Int: WorkoutSpec]
    @State private var draftIntensityFactor: Double
    /// 新增模式：使用者已經決定過（指派範本或設休息）的天數索引。編輯模式不使用（永遠視為全部已決定）。
    @State private var touchedDays: Set<Int> = []

    @State private var previewTotalLength = 28
    @State private var isCustomTotalLength = false
    @State private var showCycleLengthEditor = false
    @State private var pickingDay: EditingDay?
    @State private var showDeleteConfirm = false
    /// 14b：正在編輯覆寫值的那一天（nil＝沒有 sheet 開著）。
    @State private var overridingDay: Int?

    private let initialName: String
    private let initialCycleLength: Int
    private let initialDays: [Int: WorkoutSpec]
    private let initialIntensityFactor: Double

    public init(
        target: Target,
        templates: [WorkoutTemplate],
        weightStep: Double,
        name: @escaping (UUID) -> String,
        onSubmit: @escaping (String, Int, [Int: WorkoutSpec], Double) async -> Void,
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
            initialCycleLength = 7
            initialDays = [:]
            initialIntensityFactor = 1.0
        case .edit(let program):
            initialName = program.name
            initialCycleLength = program.cycleLength
            initialDays = program.days
            initialIntensityFactor = program.intensityFactor
        }
        _draftName = State(initialValue: initialName)
        _draftCycleLength = State(initialValue: initialCycleLength)
        _draftDays = State(initialValue: initialDays)
        _draftIntensityFactor = State(initialValue: initialIntensityFactor)
        _previewTotalLength = State(initialValue: [10, 14, 28].first { $0 >= initialCycleLength } ?? initialCycleLength)
    }

    private var isCreating: Bool {
        if case .create = target { true } else { false }
    }

    private var unassignedCount: Int {
        guard isCreating else { return 0 }
        return (0..<draftCycleLength).filter { !touchedDays.contains($0) }.count
    }

    private var nextUntouchedDay: Int? {
        guard isCreating else { return nil }
        return (0..<draftCycleLength).first { !touchedDays.contains($0) }
    }

    private var canSave: Bool {
        guard !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if isCreating { return unassignedCount == 0 }
        return draftName != initialName || draftCycleLength != initialCycleLength || draftDays != initialDays
            || draftIntensityFactor != initialIntensityFactor
    }

    /// 最近用過的範本（依 `updatedAt` 新到舊，取前 5）：picker 的「最近用過」分組。
    private var recentTemplateIds: [UUID] {
        templates.sorted { $0.updatedAt > $1.updatedAt }.prefix(5).map(\.id)
    }

    public var body: some View {
        EditScaffold(
            title: $draftName,
            titlePrompt: localText("program.name.placeholder"),
            canSave: canSave,
            cancelLabel: localText("plan.cancel"),
            saveLabel: localText("plan.save"),
            onCancel: { dismiss() },
            onSave: {
                Task {
                    await onSubmit(draftName, draftCycleLength, draftDays, draftIntensityFactor)
                    dismiss()
                }
            }
        ) {
            totalLengthSection
            cycleSection
            previewSection
            intensitySection
            if !isCreating {
                deleteSection
            }
        }
        .onChange(of: draftCycleLength) { _, newValue in
            touchedDays = touchedDays.filter { $0 < newValue }
        }
        .sheet(item: $pickingDay) { editing in
            let index = editing.index
            PickerSheet(
                title: Text(verbatim: String(localized: "program.picker.title", bundle: .module)),
                searchPrompt: localText("rotation.picker.searchPrompt"),
                allItems: dayPickerItems,
                recentItemIds: recentTemplateIds,
                selection: .single(onSelect: { item in assignDay(index, item) }),
                labels: PlanPickerLabels.standard
            )
        }
        .sheet(isPresented: Binding(
            get: { overridingDay != nil },
            set: { if !$0 { overridingDay = nil } }
        )) {
            if let day = overridingDay {
                intensityOverrideSheet(for: day)
            }
        }
        .tlConfirmationDialog(
            isPresented: $showDeleteConfirm,
            title: localText("program.delete.confirm.title"),
            message: localText("program.delete.confirm.message"),
            confirmLabel: localText("plan.delete"),
            cancelLabel: localText("plan.cancel"),
            role: .destructive,
            confirmIdentifier: "confirmDeleteProgramFromEditor",
            onConfirm: {
                Task {
                    await onDelete()
                    dismiss()
                }
            }
        )
    }

    private var dayPickerItems: [DayAssignmentPickerItem] {
        let rest = DayAssignmentPickerItem.rest(
            title: String(localized: "program.day.setRest", bundle: .module),
            subtitle: String(localized: "program.picker.restSubtitle", bundle: .module)
        )
        return [rest] + templates.map { DayAssignmentPickerItem.template($0, name: name) }
    }

    // MARK: - 總長度（畫面用，決定預覽格畫幾輪，不進 Domain）

    private var totalLengthSection: some View {
        EditSection(localText("program.totalLength.section")) {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach([10, 14, 28], id: \.self) { preset in
                    SelectableChip(
                        totalLengthLabel(preset),
                        isSelected: !isCustomTotalLength && previewTotalLength == preset,
                        selectedFill: TLColor.accent,
                        selectedText: TLColor.bg,
                        onTap: {
                            isCustomTotalLength = false
                            previewTotalLength = preset
                        }
                    )
                }
                SelectableChip(
                    customTotalLengthLabel,
                    isSelected: isCustomTotalLength,
                    selectedFill: TLColor.accent,
                    selectedText: TLColor.bg,
                    onTap: { isCustomTotalLength = true }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isCustomTotalLength {
                Stepper(value: $previewTotalLength, in: max(draftCycleLength, 1)...120) {
                    HStack {
                        localText("program.totalLength.custom")
                        Spacer()
                        Text(verbatim: "\(previewTotalLength)").foregroundStyle(TLColor.neutral600)
                    }
                }
                .padding(.horizontal, TLSpace.rowInset)
            }
        }
    }

    private func totalLengthLabel(_ n: Int) -> String {
        String(localized: "program.totalLength.days \(n)", bundle: .module)
    }

    private var customTotalLengthLabel: String {
        String(localized: "program.totalLength.custom", bundle: .module)
    }

    // MARK: - 週期（真正的 Domain 欄位：cycleLength／days）

    private var cycleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                localText("program.cycle.header \(draftCycleLength)"),
                actionLabel: localText("program.cycle.changeLength"),
                action: { showCycleLengthEditor.toggle() }
            )
            if showCycleLengthEditor {
                Stepper(value: $draftCycleLength, in: 1...60) {
                    HStack {
                        localText("program.cycleLength")
                        Spacer()
                        Text(verbatim: "\(draftCycleLength)").foregroundStyle(TLColor.neutral600)
                    }
                }
                .padding(.horizontal, TLSpace.rowInset)
                .padding(.bottom, 8)
            }
            TLGroup {
                ForEach(Array(0..<draftCycleLength), id: \.self) { index in
                    dayRow(index)
                }
            }
        }
    }

    private enum DayCellState { case assigned, rest, unassigned }

    private func cellState(_ day: Int) -> DayCellState {
        guard isCreating, !touchedDays.contains(day) else {
            return draftDays[day] != nil ? .assigned : .rest
        }
        return .unassigned
    }

    private func dayRow(_ index: Int) -> some View {
        let spec = draftDays[index]
        let state = cellState(index)
        let isNext = index == nextUntouchedDay
        return ListRow(
            title: rowTitle(state: state, isNext: isNext, spec: spec),
            subtitle: spec.map { Text(PlanFormatting.exerciseNamesSummary($0, name: name)) },
            showChevron: true,
            onTap: { pickingDay = EditingDay(index: index) },
            leading: { indexBadge(index + 1, state: state, isNext: isNext) },
            trailing: {
                // 休息日沒有重量可算，強度覆寫膠囊只在指派了範本的天顯示（14b）。
                if state == .assigned {
                    IntensityOverridePill(
                        factor: spec?.intensityFactor,
                        baselineLabel: String(localized: "rotation.intensity.baseline", bundle: .module),
                        onTap: { overridingDay = index }
                    )
                }
            }
        )
        .background(isNext ? TLColor.accent.opacity(0.07) : Color.clear)
    }

    private func rowTitle(state: DayCellState, isNext: Bool, spec: WorkoutSpec?) -> Text {
        if isNext { return localText("program.day.nextPrompt") }
        switch state {
        case .assigned: return spec.map { Text(verbatim: $0.name) } ?? localText("program.day.rest")
        case .rest: return localText("program.day.rest")
        case .unassigned: return localText("program.day.unassigned")
        }
    }

    @ViewBuilder
    private func indexBadge(_ n: Int, state: DayCellState, isNext: Bool) -> some View {
        if state == .unassigned && !isNext {
            ZStack {
                Circle()
                    .strokeBorder(TLColor.text.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Text(verbatim: "\(n)")
                    .font(TLFont.display(15))
                    .foregroundStyle(TLColor.neutral400)
            }
            .frame(width: TLSize.badge, height: TLSize.badge)
        } else {
            CircleBadge(fill: isNext ? TLColor.accent : (state == .rest ? TLColor.neutral200 : TLColor.accent200)) {
                Text(verbatim: "\(n)")
                    .font(TLFont.display(15))
                    .foregroundStyle(isNext ? TLColor.bg : (state == .rest ? TLColor.neutral500 : TLColor.accent800))
            }
        }
    }

    // MARK: - 預覽格（7 欄 × N 列，填色＝訓練日；新增模式未指派格畫虛線）

    private var rounds: Int {
        max(1, Int((Double(previewTotalLength) / Double(max(1, draftCycleLength))).rounded()))
    }

    private var practiceCountPerCycle: Int {
        (0..<draftCycleLength).filter { draftDays[$0] != nil }.count
    }

    private var previewSection: some View {
        EditSection(localText("program.preview.section")) {
            VStack(alignment: .leading, spacing: TLSpace.gapM) {
                previewGrid
                previewSummary
                    .font(TLFont.zh(TLFont.rowSub, .semibold))
                    .foregroundStyle(TLColor.neutral700)
            }
            .padding(TLSpace.rowInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TLColor.neutral300)
            .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
        }
    }

    private var previewGrid: some View {
        HStack(spacing: 4) {
            ForEach(0..<draftCycleLength, id: \.self) { day in
                VStack(spacing: 4) {
                    ForEach(0..<rounds, id: \.self) { _ in
                        previewCell(cellState(day))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func previewCell(_ state: DayCellState) -> some View {
        switch state {
        case .assigned:
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(TLColor.accent)
                .frame(width: 18, height: 18)
        case .rest:
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(TLColor.neutral100)
                .frame(width: 18, height: 18)
        case .unassigned:
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(TLColor.text.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .frame(width: 18, height: 18)
        }
    }

    @ViewBuilder
    private var previewSummary: some View {
        if unassignedCount > 0 {
            localText("program.preview.unassigned \(unassignedCount)")
        } else {
            let restCount = draftCycleLength - practiceCountPerCycle
            localText("program.preview.cycle \(draftCycleLength)")
                + Text(verbatim: " · ")
                + localText("program.preview.split \(practiceCountPerCycle) \(restCount)")
                + Text(verbatim: " · ")
                + localText("program.preview.repeat \(rounds)")
                + Text(verbatim: " = ")
                + localText("program.preview.total \(rounds * draftCycleLength) \(rounds * practiceCountPerCycle)")
        }
    }

    // MARK: - 強度基準（14b）

    /// 「套用後」試算：拿目前週期裡第一個已指派的範本、它的第一組當代表動作。
    private var intensityPreviewLines: [IntensityFactorGroup.PreviewLine] {
        guard let firstSet = draftDays.values.first?.sets.first else { return [] }
        // 帶著單位一起算：使用者可能用 lb，寫死 kg 會標錯。
        let baseWeight = firstSet.targetWeight?.resolvedWeight ?? Weight(value: 60, unit: .kg)
        let base = baseWeight.value
        // 跟投影收斂用同一個取整（WeightRange.steppedDown），否則預覽與實際排出來的數字會兜不攏。
        let result = WeightRange.steppedDown(base * draftIntensityFactor, step: weightStep)
        return [
            IntensityFactorGroup.PreviewLine(
                label: Text(verbatim: "\(name(firstSet.exerciseId)) ") + localText("template.setNumber \(firstSet.setIndex + 1)"),
                expression: Text(verbatim: String(
                    format: "%@ × %.0f%%", baseWeight.displayString, draftIntensityFactor * 100
                )),
                result: Text(verbatim: Weight(value: result, unit: baseWeight.unit).displayString)
            )
        ]
    }

    private var intensitySection: some View {
        EditSection(localText("rotation.intensity.section"), footer: localText("program.intensity.footer")) {
            IntensityFactorGroup(
                factor: $draftIntensityFactor,
                customLabel: String(localized: "rotation.intensity.custom", bundle: .module),
                previewLines: intensityPreviewLines
            )
        }
    }

    /// 點某一天的強度膠囊：ValuePicker 選 0.5–1.2，或「使用基準」清掉覆寫。
    private func intensityOverrideSheet(for day: Int) -> some View {
        IntensityOverrideSheet(
            baseline: draftIntensityFactor,
            current: draftDays[day]?.intensityFactor,
            onCancel: { overridingDay = nil },
            onUseBaseline: {
                draftDays[day]?.intensityFactor = nil
                overridingDay = nil
            },
            onCommit: { newValue in
                draftDays[day]?.intensityFactor = newValue
                overridingDay = nil
            }
        )
    }

    // MARK: - 刪除（僅編輯模式）

    private var deleteSection: some View {
        TLGroup {
            SettingsRow(
                localText("program.delete.thisProgram"),
                role: .destructive,
                onTap: { showDeleteConfirm = true }
            )
        }
        .accessibilityIdentifier("deleteProgramButton")
    }

    // MARK: - 指派

    private func assignDay(_ index: Int, _ item: DayAssignmentPickerItem) {
        switch item {
        case .rest:
            draftDays[index] = nil
        case .template(let id, _, _):
            guard let template = templates.first(where: { $0.id == id }) else { return }
            draftDays[index] = WorkoutSpec(
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
        touchedDays.insert(index)
    }
}

private struct EditingDay: Identifiable {
    let index: Int
    var id: Int { index }
}
