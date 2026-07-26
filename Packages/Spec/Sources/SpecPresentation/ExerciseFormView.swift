import DesignSystem
import SharedKernel
import SpecDomain
import SwiftUI

/// 新增／編輯動作（設計稿 9a）。套 DesignSystem `EditScaffold`：inline 標題＝名稱、
/// 肌群（單選 sage）／器材（單選 accent＋遞增 hint）／備註／被使用於（編輯模式護欄）／刪除列。
/// ⚠️ 沒有組數／次數／休息／重量 —— 那些屬於範本（設計原則 9）。
struct ExerciseFormView: View {
    let target: FormTarget
    let loadUsages: (UUID) async -> [ExerciseUsageRef]
    let onSubmit: (String, MuscleGroup, Equipment, String?) async -> Void
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var muscleGroup: MuscleGroup
    @State private var equipment: Equipment
    @State private var descriptionText: String
    @State private var usages: [ExerciseUsageRef] = []
    @State private var showDeleteConfirm = false

    private let initial: (name: String, muscle: MuscleGroup, equipment: Equipment, notes: String)

    init(
        target: FormTarget,
        loadUsages: @escaping (UUID) async -> [ExerciseUsageRef] = { _ in [] },
        onSubmit: @escaping (String, MuscleGroup, Equipment, String?) async -> Void,
        onDelete: @escaping () async -> Void = {}
    ) {
        self.target = target
        self.loadUsages = loadUsages
        self.onSubmit = onSubmit
        self.onDelete = onDelete
        switch target {
        case .create:
            initial = ("", .chest, .barbell, "")
        case .edit(let exercise):
            initial = (exercise.name, exercise.muscleGroup, exercise.equipment, exercise.description ?? "")
        }
        _name = State(initialValue: initial.name)
        _muscleGroup = State(initialValue: initial.muscle)
        _equipment = State(initialValue: initial.equipment)
        _descriptionText = State(initialValue: initial.notes)
    }

    private var isCreating: Bool {
        if case .create = target { return true }
        return false
    }

    private var dirty: Bool {
        name != initial.name || muscleGroup != initial.muscle
            || equipment != initial.equipment || descriptionText != initial.notes
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (isCreating || dirty)
    }

    var body: some View {
        EditScaffold(
            title: $name,
            titlePrompt: localText("spec.name.placeholder"),
            canSave: canSave,
            cancelLabel: localText("spec.cancel"),
            saveLabel: localText("spec.save"),
            onCancel: { dismiss() },
            onSave: {
                Task {
                    await onSubmit(name, muscleGroup, equipment,
                                   descriptionText.isEmpty ? nil : descriptionText)
                    dismiss()
                }
            }
        ) {
            muscleSection
            equipmentSection
            notesSection
            if !isCreating {
                usedInSection
                deleteSection
            }
        }
        .task {
            if case .edit(let exercise) = target {
                usages = await loadUsages(exercise.id)
            }
        }
        .tlConfirmationDialog(
            isPresented: $showDeleteConfirm,
            title: localText("spec.delete.confirm.title"),
            message: localText("spec.delete.confirm.message"),
            confirmLabel: localText("spec.delete"),
            cancelLabel: localText("spec.cancel"),
            role: .destructive,
            confirmIdentifier: "confirmDeleteExercise",
            onConfirm: { Task { await onDelete(); dismiss() } }
        )
    }

    // MARK: - 肌群（單選）

    private var muscleSection: some View {
        EditSection(localText("spec.muscleGroup")) {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    SelectableChip(
                        group.displayName,
                        isSelected: muscleGroup == group,
                        selectedFill: TLColor.sage200,
                        selectedText: TLColor.sage800,
                        onTap: { muscleGroup = group }
                    )
                }
            }
        }
    }

    // MARK: - 器材（單選）＋遞增 hint

    private var equipmentSection: some View {
        EditSection(localText("spec.equipment"), footer: localText("spec.equipment.hint")) {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(Equipment.allCases, id: \.self) { item in
                    SelectableChip(
                        item.displayName,
                        isSelected: equipment == item,
                        selectedFill: TLColor.accent,
                        selectedText: TLColor.bg,
                        onTap: { equipment = item }
                    )
                }
            }
        }
    }

    // MARK: - 備註

    private var notesSection: some View {
        EditSection(localText("spec.notes.section")) {
            TextField("", text: $descriptionText, prompt: localText("spec.notes.optional"), axis: .vertical)
                .font(TLFont.zh(TLFont.rowTitle))
                .foregroundStyle(TLColor.text)
                .lineLimit(3, reservesSpace: true)
                .padding(TLSpace.rowInset)
                .background(TLColor.neutral100)
                .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
        }
    }

    // MARK: - 被使用於（編輯模式護欄）

    private var usedInSection: some View {
        EditSection(localText("spec.usedIn.section")) {
            TLGroup {
                if usages.isEmpty {
                    ListRow(title: localText("spec.usedIn.empty"))
                } else {
                    ListRow(
                        title: localText("spec.usedIn.count \(usages.count)"),
                        trailing: {
                            Text(verbatim: usages.map(\.name).joined(separator: " · "))
                                .font(TLFont.zh(TLFont.rowSub, .regular))
                                .foregroundStyle(TLColor.neutral500)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    )
                }
            }
        }
    }

    // MARK: - 刪除

    private var deleteSection: some View {
        TLGroup {
            SettingsRow(
                localText("spec.delete.exercise"),
                role: .destructive,
                onTap: { showDeleteConfirm = true }
            )
        }
        .accessibilityIdentifier("deleteExerciseButton")
    }
}
