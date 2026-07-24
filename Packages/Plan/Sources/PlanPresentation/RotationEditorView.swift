import PlanDomain
import SharedKernel
import SwiftUI

public struct RotationEditorView: View {
    @Bindable private var viewModel: RotationEditorViewModel
    @State private var editing: RotationWorkoutEdit?
    @Environment(\.locale) private var locale

    public init(viewModel: RotationEditorViewModel) {
        self.viewModel = viewModel
    }

    // 不自帶 NavigationStack：由動作庫 tab 共用的 NavigationStack push 進來。
    public var body: some View {
        List {
            Section {
                ForEach(viewModel.workouts) { row($0) }
                    .onDelete { offsets in Task { await viewModel.delete(at: offsets) } }
                    .onMove { source, dest in Task { await viewModel.move(from: source, to: dest) } }
                Button {
                    editing = .add
                } label: {
                    Label { localText("rotation.add") } icon: { Image(systemName: "plus") }
                }
            } footer: {
                localText("rotation.hint")
            }
        }
        // 循環課表名是使用者資料（verbatim）
        .navigationTitle(Text(verbatim: viewModel.name))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        #endif
        .overlay {
            if viewModel.workouts.isEmpty {
                ContentUnavailableView {
                    Label { localText("rotation.workout.empty") } icon: { Image(systemName: "arrow.triangle.2.circlepath") }
                } description: {
                    localText("rotation.empty.hint")
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(item: $editing) { edit in
            switch edit {
            case .add:
                WorkoutSpecFormView(titleKey: "rotation.new", catalog: viewModel.catalog) { name, drafts in
                    Task { await viewModel.add(name: name, drafts: drafts) }
                }
            case .edit(let spec):
                WorkoutSpecFormView(
                    titleKey: "rotation.edit",
                    name: spec.name,
                    drafts: draftsFromBlocks(spec.blocks),
                    catalog: viewModel.catalog
                ) { name, drafts in
                    Task { await viewModel.update(id: spec.id, name: name, drafts: drafts) }
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
    }

    private func row(_ spec: WorkoutSpec) -> some View {
        Button {
            editing = .edit(spec)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: spec.name).font(.headline)
                Text(PlanFormatting.summary(spec, name: viewModel.name(for:), language: AppLanguage(locale: locale)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
