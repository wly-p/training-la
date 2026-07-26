import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

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
    let onSubmit: (String, [PlanSet]) async -> Void
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var draftSets: [PlanSet]
    @State private var expandedExerciseIndex: Int?
    @State private var editingSet: EditingSet?
    @State private var pickingExercise = false
    @State private var showDeleteConfirm = false

    init(
        target: Target,
        catalog: [PlanCatalogExercise],
        onSubmit: @escaping (String, [PlanSet]) async -> Void,
        onDelete: @escaping () async -> Void = {}
    ) {
        self.target = target
        self.catalog = catalog
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
            statsLine
            exercisesSection
            if !isCreating {
                deleteSection
            }
        }
        .sheet(isPresented: $pickingExercise) {
            ExercisePickerSheet(catalog: catalog) { exercise in
                addExercise(exercise)
            }
        }
        .sheet(item: $editingSet) { editing in
            if let index = draftSets.firstIndex(where: { $0.id == editing.setId }) {
                SetEditSheet(
                    exerciseName: name(for: editing.exerciseId),
                    setNumber: editing.setNumber,
                    weightStep: weightStep(for: editing.exerciseId),
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
        if expandedExerciseIndex == block.exerciseIndex {
            expandedBlock(block)
        } else {
            collapsedRow(block)
        }
    }

    private func collapsedRow(_ block: PlanBlock) -> some View {
        ListRow(
            title: Text(verbatim: name(for: block.exerciseId)),
            subtitle: subtitle(for: block.sets),
            onTap: { expandedExerciseIndex = block.exerciseIndex },
            trailing: { capsule(for: block.sets) }
        )
        .contextMenu { blockMenu(block) }
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

    private func addExercise(_ exercise: PlanCatalogExercise) {
        let newIndex = blocks.count
        let sets = (0..<3).map { i in
            PlanSet(id: UUID(), exerciseId: exercise.id, exerciseIndex: newIndex, setIndex: i, targetWeight: nil, targetReps: 10, restSec: 60)
        }
        draftSets.append(contentsOf: sets)
        expandedExerciseIndex = newIndex
    }

    private func moveBlock(_ index: Int, direction: Int) {
        var reordered = blocks
        let target = index + direction
        guard reordered.indices.contains(index), reordered.indices.contains(target) else { return }
        reordered.swapAt(index, target)
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

/// 逐組編輯：單組的重量表達式（絕對值／相對上次）＋次數。用 `ValuePicker` 選值。
private struct SetEditSheet: View {
    let exerciseName: String
    let setNumber: Int
    let weightStep: Double
    @Binding var targetWeight: WeightExpression?
    @Binding var targetReps: Int?

    @Environment(\.dismiss) private var dismiss
    @State private var isRelative: Bool
    @State private var weightValue: Double
    @State private var repsValue: Double

    init(
        exerciseName: String,
        setNumber: Int,
        weightStep: Double,
        targetWeight: Binding<WeightExpression?>,
        targetReps: Binding<Int?>
    ) {
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.weightStep = weightStep
        self._targetWeight = targetWeight
        self._targetReps = targetReps
        switch targetWeight.wrappedValue {
        case .relativeToLast(let delta):
            _isRelative = State(initialValue: true)
            _weightValue = State(initialValue: delta.value)
        case .absolute(let w):
            _isRelative = State(initialValue: false)
            _weightValue = State(initialValue: w.value)
        case nil:
            _isRelative = State(initialValue: false)
            _weightValue = State(initialValue: 20)
        }
        _repsValue = State(initialValue: Double(targetReps.wrappedValue ?? 10))
    }

    private var weightValues: [Double] {
        isRelative
            ? Array(stride(from: -50, through: 50, by: weightStep))
            : Array(stride(from: 0, through: 300, by: weightStep))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapL) {
            topBar
            modeChips
            ValuePicker(
                value: $weightValue,
                values: weightValues,
                kicker: isRelative ? "相對上次（公斤）" : "重量（公斤）",
                quickActions: [
                    .init("-\(formatNumber(weightStep))") {
                        weightValue = max(weightValues.first ?? 0, weightValue - weightStep)
                    },
                    .init("+\(formatNumber(weightStep))") {
                        weightValue = min(weightValues.last ?? 0, weightValue + weightStep)
                    },
                ]
            )
            ValuePicker(value: $repsValue, values: Array(stride(from: 1, through: 30, by: 1)), kicker: "次數")
        }
        .padding(TLSpace.page)
        .padding(.top, TLSpace.gapL)
        .background(TLColor.bg.ignoresSafeArea())
        .presentationDetents([.medium])
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
                targetWeight = isRelative
                    ? .relativeToLast(delta: Weight(value: weightValue, unit: .kg))
                    : .absolute(Weight(value: weightValue, unit: .kg))
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
                "絕對值", isSelected: !isRelative, selectedFill: TLColor.accent, selectedText: TLColor.bg,
                onTap: { isRelative = false }
            )
            SelectableChip(
                "相對上次", isSelected: isRelative, selectedFill: TLColor.accent, selectedText: TLColor.bg,
                onTap: { isRelative = true }
            )
        }
    }
}

/// 從動作庫挑一個加進範本（設計稿：清單最後一列「從動作庫加入」）。
private struct ExercisePickerSheet: View {
    let catalog: [PlanCatalogExercise]
    let onSelect: (PlanCatalogExercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var visible: [PlanCatalogExercise] {
        guard !searchText.isEmpty else { return catalog }
        return catalog.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(visible) { exercise in
                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    HStack {
                        Text(verbatim: exercise.name)
                        Spacer()
                        Text(verbatim: exercise.muscleGroup.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: localText("plan.searchExercises"))
            .navigationTitle(localText("plan.addExercise"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("plan.cancel") }
                }
            }
            .overlay {
                if catalog.isEmpty {
                    ContentUnavailableView {
                        Label { localText("plan.emptyLibrary") } icon: { Image(systemName: "books.vertical") }
                    } description: {
                        localText("plan.emptyLibrary.hint")
                    }
                }
            }
        }
    }
}
