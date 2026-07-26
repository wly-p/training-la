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
    let name: (UUID) -> String
    let onSubmit: (String, [WorkoutSpec], Bool, Int) async -> Void
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftName: String
    @State private var draftWorkouts: [WorkoutSpec]
    @State private var pickingTemplates = false
    @State private var selectedTemplateIds: Set<UUID> = []
    @State private var isActiveOnCreate = true
    @State private var startAtDay = 1
    @State private var showStartDayEditor = false
    @State private var showDeleteConfirm = false

    private let initialName: String
    private let initialWorkouts: [WorkoutSpec]

    public init(
        target: Target,
        templates: [WorkoutTemplate],
        name: @escaping (UUID) -> String,
        onSubmit: @escaping (String, [WorkoutSpec], Bool, Int) async -> Void,
        onDelete: @escaping () async -> Void = {}
    ) {
        self.target = target
        self.templates = templates
        self.name = name
        self.onSubmit = onSubmit
        self.onDelete = onDelete
        switch target {
        case .create:
            initialName = ""
            initialWorkouts = []
        case .edit(let rotation):
            initialName = rotation.name
            initialWorkouts = rotation.workouts
        }
        _draftName = State(initialValue: initialName)
        _draftWorkouts = State(initialValue: initialWorkouts)
    }

    private var isCreating: Bool {
        if case .create = target { true } else { false }
    }

    private var canSave: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draftWorkouts.isEmpty
            && (isCreating || draftName != initialName || draftWorkouts != initialWorkouts)
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
                    await onSubmit(draftName, draftWorkouts, isActiveOnCreate, startAtDay - 1)
                    dismiss()
                }
            }
        ) {
            statsLine
            workoutsSection
            hintLine
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
            trailing: { RowValue("\(spec.sets.count)", unit: String(localized: "rotation.setsUnit", bundle: .module)) }
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
