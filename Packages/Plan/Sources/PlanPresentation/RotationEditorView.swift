import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

/// 單一循環課表的內容編輯器（設計稿骨架：同 9c 一套，但沒有總長度／休息 —— 循環不綁日期，只有範本順序）。
/// 本地草稿（名稱／範本順序）只在按「儲存」時一次寫回；排序用 contextMenu 上移／下移／移除
/// （避開左滑／拖曳手勢在自訂容器內的已知陷阱，見 memory `nav-drill-in-pitfall`）。
/// 不自帶 NavigationStack：由動作庫 tab 共用的 NavigationStack push 進來。
public struct RotationEditorView: View {
    @Bindable private var viewModel: RotationEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var draftName = ""
    @State private var draftWorkouts: [WorkoutSpec] = []
    @State private var editing: RotationWorkoutEdit?
    @State private var showDeleteConfirm = false

    public init(viewModel: RotationEditorViewModel) {
        self.viewModel = viewModel
    }

    private var canSave: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (draftName != viewModel.name || draftWorkouts != viewModel.workouts)
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
                    if await viewModel.save(name: draftName, workouts: draftWorkouts) {
                        dismiss()
                    }
                }
            }
        ) {
            workoutsSection
            deleteSection
        }
        .task {
            await viewModel.load()
            draftName = viewModel.name
            draftWorkouts = viewModel.workouts
        }
        .sheet(item: $editing) { edit in
            switch edit {
            case .add:
                WorkoutSpecFormView(
                    titleKey: "rotation.new",
                    catalog: viewModel.catalog,
                    templates: viewModel.templates
                ) { name, drafts in
                    draftWorkouts.append(WorkoutSpec(name: name, sets: PlanSet.make(from: drafts)))
                }
            case .edit(let spec):
                WorkoutSpecFormView(
                    titleKey: "rotation.edit",
                    name: spec.name,
                    drafts: draftsFromBlocks(spec.blocks),
                    catalog: viewModel.catalog,
                    templates: viewModel.templates
                ) { name, drafts in
                    if let index = draftWorkouts.firstIndex(where: { $0.id == spec.id }) {
                        draftWorkouts[index] = WorkoutSpec(id: spec.id, name: name, sets: PlanSet.make(from: drafts))
                    }
                }
            }
        }
        .alert(
            localText("plan.error"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button(role: .cancel) {} label: { localText("plan.ok") }
        } message: {
            Text(viewModel.errorMessage ?? "")
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
                    if await viewModel.delete() { dismiss() }
                }
            }
        )
    }

    // MARK: - 範本順序

    private var workoutsSection: some View {
        EditSection(localText("rotation.workouts.section"), footer: localText("rotation.hint")) {
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
            subtitle: Text(PlanFormatting.summary(spec, name: viewModel.name(for:), language: AppLanguage(locale: locale))),
            showChevron: true,
            onTap: { editing = .edit(spec) },
            leading: { CircleBadge(count: index + 1) }
        )
        .contextMenu {
            Button {
                guard index > 0 else { return }
                draftWorkouts.swapAt(index, index - 1)
            } label: {
                Label { localText("rotation.reorder.up") } icon: { Image(systemName: "arrow.up") }
            }
            .disabled(index == 0)
            Button {
                guard index < draftWorkouts.count - 1 else { return }
                draftWorkouts.swapAt(index, index + 1)
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

    private var addRow: some View {
        ListRow(
            title: localText("rotation.add"),
            onTap: { editing = .add },
            leading: { CircleBadge(icon: "plus", fill: TLColor.neutral200, tint: TLColor.neutral600) }
        )
    }

    // MARK: - 刪除

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
}

enum RotationWorkoutEdit: Identifiable {
    case add
    case edit(WorkoutSpec)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let spec): spec.id.uuidString
        }
    }
}
