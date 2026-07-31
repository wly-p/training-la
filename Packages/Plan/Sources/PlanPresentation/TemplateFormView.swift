import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI
import UniformTypeIdentifiers

/// 課表範本編輯（設計稿 9b/11b）：套 `EditScaffold`。逐組編輯——每個動作收起顯示摘要膠囊，
/// 點膠囊/整列展開才逐組編輯（組N／重量表達式／次數）。重量表達式只支援絕對值／相對上次，
/// **不做 %1RM**（本次設計範圍外，見動作庫 v3 README J 節）。
struct TemplateFormView: View {
    enum Target {
        case create
        case edit(WorkoutTemplate)
    }

    let target: Target
    let catalog: [PlanCatalogExercise]
    /// 最近用過的動作 id（picker 的「最近用過」分組；由呼叫端算好傳入，見 TemplateListView）。
    let recentExerciseIds: [UUID]
    /// 14a 複製範本：剛複製進來時的來源範本名，只在這次開表單顯示一次（存檔後消失，
    /// 呼叫端下次正常編輯不會再傳這個）。
    let duplicatedFromName: String?
    let onSubmit: (String, [PlanSet]) async -> Void
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var draftSets: [PlanSet]
    @State private var expandedExerciseIndex: Int?
    @State private var editingSet: EditingSet?
    @State private var pickingExercise = false
    @State private var selectedExerciseIds: Set<UUID> = []
    @State private var showDeleteConfirm = false

    init(
        target: Target,
        catalog: [PlanCatalogExercise],
        recentExerciseIds: [UUID] = [],
        duplicatedFromName: String? = nil,
        onSubmit: @escaping (String, [PlanSet]) async -> Void,
        onDelete: @escaping () async -> Void = {}
    ) {
        self.target = target
        self.catalog = catalog
        self.recentExerciseIds = recentExerciseIds
        self.duplicatedFromName = duplicatedFromName
        self.onSubmit = onSubmit
        self.onDelete = onDelete
        switch target {
        case .create:
            _name = State(initialValue: "")
            _draftSets = State(initialValue: [])
        case .edit(let template):
            _name = State(initialValue: template.name)
            _draftSets = State(initialValue: template.sets)
        }
    }

    private var isCreating: Bool {
        if case .create = target { return true }
        return false
    }

    private var blocks: [PlanBlock] { draftSets.planBlocks }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !draftSets.isEmpty
    }

    var body: some View {
        EditScaffold(
            title: $name,
            titlePrompt: localText("template.name.placeholder"),
            canSave: canSave,
            cancelLabel: localText("plan.cancel"),
            saveLabel: localText("plan.save"),
            onCancel: { dismiss() },
            onSave: {
                Task {
                    await onSubmit(name, draftSets)
                    dismiss()
                }
            }
        ) {
            if let duplicatedFromName {
                duplicatedFromBanner(duplicatedFromName)
            } else {
                statsLine
            }
            exercisesSection
            if !isCreating {
                deleteSection
            }
        }
        .sheet(isPresented: $pickingExercise) {
            PickerSheet(
                title: Text(verbatim: String(localized: "plan.addExercise", bundle: .module)),
                searchPrompt: localText("plan.searchExercises"),
                allItems: catalog.map(ExercisePickerItem.init),
                recentItemIds: recentExerciseIds,
                filters: MuscleGroup.allCases.map { PickerSheetFilterChip(id: $0.rawValue, label: $0.displayName) },
                matchesFilter: { item, filter in item.exercise.muscleGroup.rawValue == filter.id },
                selection: .multiple(
                    selectedIds: $selectedExerciseIds,
                    confirmLabel: { count in localText("template.picker.addCount \(count)") },
                    onConfirm: addSelectedExercises
                ),
                labels: PlanPickerLabels.standard
            )
        }
        .sheet(item: $editingSet) { editing in
            if let index = draftSets.firstIndex(where: { $0.id == editing.setId }) {
                let current = draftSets[index]
                let previous = draftSets.first {
                    $0.exerciseIndex == current.exerciseIndex && $0.setIndex == current.setIndex - 1
                }
                SetEditSheet(
                    exerciseName: name(for: editing.exerciseId),
                    setNumber: editing.setNumber,
                    weightStep: weightStep(for: editing.exerciseId),
                    previousWeight: previous?.targetWeight,
                    previousReps: previous?.targetReps,
                    targetWeight: $draftSets[index].targetWeight,
                    targetReps: $draftSets[index].targetReps
                )
            }
        }
        .tlConfirmationDialog(
            isPresented: $showDeleteConfirm,
            title: localText("template.delete.confirm.title"),
            message: localText("template.delete.confirm.message"),
            confirmLabel: localText("template.delete"),
            cancelLabel: localText("plan.cancel"),
            role: .destructive,
            confirmIdentifier: "confirmDeleteTemplate",
            onConfirm: { Task { await onDelete(); dismiss() } }
        )
    }

    // MARK: - 即時統計

    private var estimatedMinutes: Int {
        let restTotal = draftSets.reduce(0) { $0 + ($1.restSec ?? 60) }
        let workTotal = draftSets.count * 40
        return max(1, Int((Double(restTotal + workTotal) / 60).rounded()))
    }

    private var statsLine: some View {
        (localText("template.stats.exercises \(blocks.count)")
            + Text(verbatim: " · ")
            + localText("template.stats.sets \(draftSets.count)")
            + Text(verbatim: " · ")
            + localText("template.stats.minutes \(estimatedMinutes)"))
            .font(TLFont.zh(TLFont.rowSub, .semibold))
            .foregroundStyle(TLColor.neutral500)
    }

    /// 14a：只在剛複製那次顯示，存檔後這個 View instance 就會被 dismiss，不會殘留。
    /// accent-700 ＋複製圖示，一行文字（來源＋即時統計），設計稿 02-library.md B2 節。
    private func duplicatedFromBanner(_ originalName: String) -> some View {
        let statsText = String(
            localized: "template.stats.summary \(blocks.count) \(draftSets.count) \(estimatedMinutes)",
            bundle: .module
        )
        let sourceText = String(localized: "template.duplicatedFrom \(originalName)", bundle: .module)
        return (Text(Image(systemName: "doc.on.doc")) + Text(verbatim: "  \(sourceText) · \(statsText)"))
            .font(TLFont.zh(TLFont.rowSub, .semibold))
            .foregroundStyle(TLColor.accent700)
    }

    // MARK: - 動作清單

    private var exercisesSection: some View {
        EditSection(localText("template.exercises.section")) {
            TLGroup {
                ForEach(blocks) { block in
                    blockView(block)
                }
                addExerciseRow
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: PlanBlock) -> some View {
        Group {
            if expandedExerciseIndex == block.exerciseIndex {
                expandedBlock(block)
            } else {
                collapsedRow(block)
            }
        }
        // 長按拖曳排序（設計稿 9b/11b 的「=」把手）：系統原生拖放，不會跟點擊展開／捲動打架
        // （跟 8b 那個自訂水平滑動手勢是不同類，見 memory nav-drill-in-pitfall）。
        .draggable(TemplateBlockTransfer(exerciseIndex: block.exerciseIndex))
        .dropDestination(for: TemplateBlockTransfer.self) { items, _ in
            guard let dragged = items.first else { return false }
            moveBlock(fromExerciseIndex: dragged.exerciseIndex, toExerciseIndex: block.exerciseIndex)
            return true
        }
    }

    private func collapsedRow(_ block: PlanBlock) -> some View {
        ListRow(
            title: Text(verbatim: name(for: block.exerciseId)),
            subtitle: subtitle(for: block.sets),
            onTap: { expandedExerciseIndex = block.exerciseIndex },
            leading: { dragHandle },
            trailing: { capsule(for: block.sets) }
        )
        .contextMenu { blockMenu(block) }
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(TLColor.neutral400)
    }

    private func capsule(for sets: [PlanSet]) -> some View {
        Text(verbatim: capsuleText(for: sets))
            .font(TLFont.display(15))
            .foregroundStyle(TLColor.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(TLColor.neutral200))
    }

    @ViewBuilder
    private func blockMenu(_ block: PlanBlock) -> some View {
        let index = blocks.firstIndex(where: { $0.exerciseIndex == block.exerciseIndex }) ?? 0
        Button {
            moveBlock(index, direction: -1)
        } label: {
            Label { localText("template.reorder.up") } icon: { Image(systemName: "arrow.up") }
        }
        .disabled(index == 0)
        Button {
            moveBlock(index, direction: 1)
        } label: {
            Label { localText("template.reorder.down") } icon: { Image(systemName: "arrow.down") }
        }
        .disabled(index == blocks.count - 1)
        Button(role: .destructive) {
            removeBlock(at: index)
        } label: {
            Label { localText("template.reorder.remove") } icon: { Image(systemName: "trash") }
        }
    }

    // MARK: - 展開的動作區塊

    private func expandedBlock(_ block: PlanBlock) -> some View {
        VStack(alignment: .leading, spacing: TLSpace.gapM) {
            HStack {
                Text(verbatim: name(for: block.exerciseId))
                    .font(TLFont.zh(TLFont.cardTitle, .bold))
                    .foregroundStyle(TLColor.text)
                Spacer()
                Button {
                    expandedExerciseIndex = nil
                } label: {
                    localText("template.collapse")
                }
                .buttonStyle(.tlText)
            }
            ForEach(block.sets) { set in
                setRow(set, exerciseId: block.exerciseId)
            }
            shortcutRow(block)
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.neutral200)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.inner, style: .continuous))
        .contextMenu { blockMenu(block) }
    }

    private func setRow(_ set: PlanSet, exerciseId: UUID) -> some View {
        HStack {
            localText("template.setNumber \(set.setIndex + 1)")
                .font(TLFont.zh(TLFont.rowSub, .semibold))
                .foregroundStyle(TLColor.neutral600)
                .frame(width: 48, alignment: .leading)
            Button {
                editingSet = EditingSet(exerciseId: exerciseId, setId: set.id, setNumber: set.setIndex + 1)
            } label: {
                HStack(spacing: 4) {
                    Text(verbatim: weightLabel(for: set.targetWeight))
                        .font(TLFont.display(16))
                        .foregroundStyle(TLColor.text)
                    Spacer()
                    Text(verbatim: "× \(set.targetReps ?? 0)")
                        .font(TLFont.zh(TLFont.rowTitle, .semibold))
                        .foregroundStyle(TLColor.neutral700)
                }
                .padding(.horizontal, TLSpace.rowInset)
                .padding(.vertical, 12)
                .background(TLColor.bg)
                .clipShape(RoundedRectangle(cornerRadius: TLRadius.inner, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button(role: .destructive) {
                removeSet(exerciseIndex: set.exerciseIndex, setId: set.id)
            } label: {
                Label { localText("template.set.remove") } icon: { Image(systemName: "trash") }
            }
        }
    }

    private func shortcutRow(_ block: PlanBlock) -> some View {
        HStack(spacing: 8) {
            shortcutButton(localText("template.shortcut.same")) { applySameForAll(exerciseIndex: block.exerciseIndex) }
            shortcutButton(localText("template.shortcut.progressive")) {
                applyProgressive(exerciseIndex: block.exerciseIndex, step: weightStep(for: block.exerciseId))
            }
            shortcutButton(localText("template.shortcut.addSet")) { addSet(exerciseIndex: block.exerciseIndex) }
        }
    }

    private func shortcutButton(_ label: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label
                .font(TLFont.zh(TLFont.rowSub, .semibold))
                .foregroundStyle(TLColor.accent700)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(TLColor.bg))
        }
        .buttonStyle(.plain)
    }

    private var addExerciseRow: some View {
        ListRow(
            title: localText("template.addExercise"),
            onTap: { pickingExercise = true },
            leading: { CircleBadge(icon: "plus", fill: TLColor.neutral200, tint: TLColor.neutral600) }
        )
    }

    // MARK: - 刪除

    private var deleteSection: some View {
        TLGroup {
            SettingsRow(
                localText("template.delete.thisTemplate"),
                role: .destructive,
                onTap: { showDeleteConfirm = true }
            )
        }
        .accessibilityIdentifier("deleteTemplateButton")
    }

    // MARK: - 草稿操作

    /// 多選加入：選中的動作各自新增一個區塊（3 組、次數 10、休息 60 秒的預設值），接在清單最後——
    /// 跟設計稿「加入的動作出現在『從動作庫加入』正上方」一致。`selectedExerciseIds` 是 Set（無序），
    /// 用 catalog 原本的順序枚舉取代，順序至少是穩定、可預期的。
    private func addSelectedExercises() {
        var newIndex = blocks.count
        for exercise in catalog where selectedExerciseIds.contains(exercise.id) {
            let sets = (0..<3).map { i in
                PlanSet(id: UUID(), exerciseId: exercise.id, exerciseIndex: newIndex, setIndex: i, targetWeight: nil, targetReps: 10, restSec: 60)
            }
            draftSets.append(contentsOf: sets)
            newIndex += 1
        }
        selectedExerciseIds = []
    }

    private func moveBlock(_ index: Int, direction: Int) {
        var reordered = blocks
        let target = index + direction
        guard reordered.indices.contains(index), reordered.indices.contains(target) else { return }
        reordered.swapAt(index, target)
        reindex(reordered)
    }

    /// 拖曳排序：把來源動作搬到目標動作的位置（其餘依序往前/往後補）。
    private func moveBlock(fromExerciseIndex: Int, toExerciseIndex: Int) {
        guard fromExerciseIndex != toExerciseIndex else { return }
        var reordered = blocks
        guard let fromIndex = reordered.firstIndex(where: { $0.exerciseIndex == fromExerciseIndex }),
              let toIndex = reordered.firstIndex(where: { $0.exerciseIndex == toExerciseIndex })
        else { return }
        let moved = reordered.remove(at: fromIndex)
        reordered.insert(moved, at: toIndex)
        reindex(reordered)
    }

    private func removeBlock(at index: Int) {
        var reordered = blocks
        guard reordered.indices.contains(index) else { return }
        reordered.remove(at: index)
        reindex(reordered)
        expandedExerciseIndex = nil
    }

    private func reindex(_ orderedBlocks: [PlanBlock]) {
        var result: [PlanSet] = []
        for (newIndex, block) in orderedBlocks.enumerated() {
            for set in block.sets {
                var updated = set
                updated.exerciseIndex = newIndex
                result.append(updated)
            }
        }
        draftSets = result
    }

    private func addSet(exerciseIndex: Int) {
        let setsInBlock = draftSets.filter { $0.exerciseIndex == exerciseIndex }.sorted { $0.setIndex < $1.setIndex }
        guard let last = setsInBlock.last else { return }
        var newSet = last
        newSet.id = UUID()
        newSet.setIndex = last.setIndex + 1
        draftSets.append(newSet)
    }

    private func removeSet(exerciseIndex: Int, setId: UUID) {
        draftSets.removeAll { $0.exerciseIndex == exerciseIndex && $0.id == setId }
        let remaining = draftSets.filter { $0.exerciseIndex == exerciseIndex }.sorted { $0.setIndex < $1.setIndex }
        for (newSetIndex, set) in remaining.enumerated() {
            if let idx = draftSets.firstIndex(where: { $0.id == set.id }) {
                draftSets[idx].setIndex = newSetIndex
            }
        }
    }

    private func applySameForAll(exerciseIndex: Int) {
        guard let first = draftSets.first(where: { $0.exerciseIndex == exerciseIndex && $0.setIndex == 0 }) else { return }
        for i in draftSets.indices where draftSets[i].exerciseIndex == exerciseIndex {
            draftSets[i].targetWeight = first.targetWeight
            draftSets[i].targetReps = first.targetReps
        }
    }

    private func applyProgressive(exerciseIndex: Int, step: Double) {
        let setsInBlock = draftSets.filter { $0.exerciseIndex == exerciseIndex }.sorted { $0.setIndex < $1.setIndex }
        guard let first = setsInBlock.first, case .absolute(let base) = first.targetWeight ?? .absolute(Weight(value: 0, unit: .kg)) else { return }
        for (offset, set) in setsInBlock.enumerated() {
            guard let idx = draftSets.firstIndex(where: { $0.id == set.id }) else { continue }
            draftSets[idx].targetWeight = .absolute(Weight(value: base.value + step * Double(offset), unit: base.unit))
        }
    }

    // MARK: - 顯示輔助

    private func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    private func weightStep(for exerciseId: UUID) -> Double {
        catalog.first { $0.id == exerciseId }?.equipment.weightStep ?? 2.5
    }

    private func weightLabel(for expression: WeightExpression?) -> String {
        switch expression {
        case nil: "—"
        case .absolute(let w): formatNumber(w.value)
        case .relativeToLast(let delta): "上次\(delta.value >= 0 ? "+" : "")\(formatNumber(delta.value))"
        case .percentOf1RM(let percent): "\(formatNumber(percent))%1RM"
        }
    }

    private enum BlockWeightMode {
        case uniform(WeightExpression?)
        case varying
    }

    private func weightMode(for sets: [PlanSet]) -> BlockWeightMode {
        guard let first = sets.first?.targetWeight else {
            return sets.allSatisfy { $0.targetWeight == nil } ? .uniform(nil) : .varying
        }
        return sets.allSatisfy { $0.targetWeight == first } ? .uniform(first) : .varying
    }

    private func subtitle(for sets: [PlanSet]) -> Text {
        switch weightMode(for: sets) {
        case .uniform(.some(.absolute)), .uniform(nil):
            localText("template.block.same \(sets.count)")
        case .uniform(.some(.relativeToLast)):
            localText("template.block.relativeToLast \(sets.count)")
        case .uniform(.some(.percentOf1RM)):
            localText("template.block.percentOf1RM \(sets.count)")
        case .varying:
            localText("template.block.progressive \(sets.count)")
        }
    }

    private func capsuleText(for sets: [PlanSet]) -> String {
        let reps = sets.first?.targetReps ?? 0
        switch weightMode(for: sets) {
        case .uniform(.some(.absolute(let w))):
            return "\(sets.count) × \(reps) @ \(formatNumber(w.value))"
        case .uniform(.some(.relativeToLast(let delta))):
            return "\(sets.count) × \(reps) 上次\(delta.value >= 0 ? "+" : "")\(formatNumber(delta.value))"
        case .uniform(.some(.percentOf1RM(let percent))):
            return "\(sets.count) × \(reps) \(formatNumber(percent))%1RM"
        case .uniform(nil):
            return "\(sets.count) × \(reps)"
        case .varying:
            return "\(sets.count) 組"
        }
    }
}

private func formatNumber(_ v: Double) -> String {
    v == v.rounded() ? String(Int(v)) : String(v)
}

private struct EditingSet: Identifiable {
    let exerciseId: UUID
    let setId: UUID
    let setNumber: Int
    var id: UUID { setId }
}

/// 動作區塊拖曳排序用的傳輸值——只在同一個編輯畫面內拖放，內容就一個 index。
private struct TemplateBlockTransfer: Codable, Transferable {
    let exerciseIndex: Int
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

/// 逐組編輯：單組的重量表達式（絕對值／相對上次）＋次數。用 `ValuePicker` 選值。
/// 逐組編輯（設計稿 4a「08 · 數值選擇器」）：重量／次數並排在同一個 `DualValuePicker`，
/// 共用一排快捷（-step/+step/同上組）。「同上組」複製前一組的重量與次數，第一組沒有上一組故不顯示。
private struct SetEditSheet: View {
    let exerciseName: String
    let setNumber: Int
    let weightStep: Double
    let previousWeight: WeightExpression?
    let previousReps: Int?
    @Binding var targetWeight: WeightExpression?
    @Binding var targetReps: Int?

    /// 三種重量表達式對應的輸入模式（見 91-weight-model.md §3：同一份範本裡逐組可混用）。
    private enum WeightInputMode: Equatable {
        case absolute
        case relativeToLast
        case percentOf1RM
    }

    @Environment(\.dismiss) private var dismiss
    @State private var mode: WeightInputMode
    @State private var weightValue: Double
    @State private var repsValue: Double

    init(
        exerciseName: String,
        setNumber: Int,
        weightStep: Double,
        previousWeight: WeightExpression?,
        previousReps: Int?,
        targetWeight: Binding<WeightExpression?>,
        targetReps: Binding<Int?>
    ) {
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.weightStep = weightStep
        self.previousWeight = previousWeight
        self.previousReps = previousReps
        self._targetWeight = targetWeight
        self._targetReps = targetReps
        switch targetWeight.wrappedValue {
        case .relativeToLast(let delta):
            _mode = State(initialValue: .relativeToLast)
            _weightValue = State(initialValue: delta.value)
        case .absolute(let w):
            _mode = State(initialValue: .absolute)
            _weightValue = State(initialValue: w.value)
        case .percentOf1RM(let percent):
            _mode = State(initialValue: .percentOf1RM)
            _weightValue = State(initialValue: percent)
        case nil:
            _mode = State(initialValue: .absolute)
            _weightValue = State(initialValue: 20)
        }
        _repsValue = State(initialValue: Double(targetReps.wrappedValue ?? 10))
    }

    /// 快捷 ±／滾輪的步階：絕對值與相對上次跟著器材遞增單位，%1RM 固定 5（百分比不是公斤）。
    private var quickStep: Double { mode == .percentOf1RM ? 5 : weightStep }

    /// 這筆絕對重量的單位；其他模式（相對增量／百分比）用不到，預設公斤。
    private var weightUnit: WeightUnit {
        if case .absolute(let w) = targetWeight { return w.unit }
        return .kg
    }

    private var weightValues: [Double] {
        switch mode {
        // 相對上次是「增減量」不是絕對重量，值域維持 ±50 不套用重量上限。
        case .relativeToLast: Array(stride(from: -50, through: 50, by: weightStep))
        case .percentOf1RM: Array(stride(from: 0, through: 100, by: 5))
        case .absolute: WeightRange.values(for: weightUnit, step: weightStep)
        }
    }

    private var repsValues: [Double] { Array(stride(from: 1, through: 30, by: 1)) }

    private var quickActions: [DualValuePicker.QuickAction] {
        var actions: [DualValuePicker.QuickAction] = [
            .init("-\(formatNumber(quickStep))") {
                weightValue = max(weightValues.first ?? 0, weightValue - quickStep)
            },
            .init("+\(formatNumber(quickStep))") {
                weightValue = min(weightValues.last ?? 0, weightValue + quickStep)
            },
        ]
        if previousWeight != nil || previousReps != nil {
            actions.append(.init(String(localized: "template.set.copyPrevious", bundle: .module), flex: 1.4) {
                switch previousWeight {
                case .absolute(let w): mode = .absolute; weightValue = w.value
                case .relativeToLast(let d): mode = .relativeToLast; weightValue = d.value
                case .percentOf1RM(let p): mode = .percentOf1RM; weightValue = p
                case nil: break
                }
                if let previousReps { repsValue = Double(previousReps) }
            })
        }
        return actions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapL) {
            topBar
            modeChips
            DualValuePicker(
                primaryValue: $weightValue,
                primaryValues: weightValues,
                primaryKicker: primaryKicker,
                secondaryValue: $repsValue,
                secondaryValues: repsValues,
                secondaryKicker: String(localized: "template.setNumber.reps", bundle: .module),
                quickActions: quickActions
            )
        }
        .padding(TLSpace.page)
        .padding(.top, TLSpace.gapL)
        .background(TLColor.bg.ignoresSafeArea())
        .presentationDetents([.height(560)])
    }

    private var primaryKicker: String {
        switch mode {
        case .relativeToLast: String(localized: "template.set.relativeKicker", bundle: .module)
        case .percentOf1RM: String(localized: "template.set.percentKicker", bundle: .module)
        case .absolute: String(localized: "template.set.weightKicker", bundle: .module)
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: { localText("plan.cancel") }
                .font(TLFont.zh(15.5, .medium))
                .foregroundStyle(TLColor.neutral600)
            Spacer()
            (Text(verbatim: exerciseName) + Text(verbatim: " · ") + localText("template.setNumber \(setNumber)"))
                .font(TLFont.zh(TLFont.rowTitle, .semibold))
                .foregroundStyle(TLColor.text)
            Spacer()
            Button {
                switch mode {
                case .relativeToLast:
                    targetWeight = .relativeToLast(delta: Weight(value: weightValue, unit: .kg))
                case .percentOf1RM:
                    targetWeight = .percentOf1RM(weightValue)
                case .absolute:
                    targetWeight = .absolute(Weight(value: weightValue, unit: .kg))
                }
                targetReps = Int(repsValue)
                dismiss()
            } label: {
                localText("plan.done")
            }
            .font(TLFont.zh(15.5, .bold))
            .foregroundStyle(TLColor.accent700)
        }
    }

    private var modeChips: some View {
        HStack(spacing: 8) {
            SelectableChip(
                String(localized: "template.set.absolute", bundle: .module), isSelected: mode == .absolute,
                selectedFill: TLColor.accent, selectedText: TLColor.bg,
                onTap: { mode = .absolute }
            )
            SelectableChip(
                String(localized: "template.set.relative", bundle: .module), isSelected: mode == .relativeToLast,
                selectedFill: TLColor.accent, selectedText: TLColor.bg,
                onTap: { mode = .relativeToLast }
            )
            SelectableChip(
                String(localized: "template.set.percent", bundle: .module), isSelected: mode == .percentOf1RM,
                selectedFill: TLColor.accent, selectedText: TLColor.bg,
                onTap: { mode = .percentOf1RM }
            )
        }
    }
}

