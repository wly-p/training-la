import PlanDomain
import SharedKernel
import SwiftUI

/// 動作庫「循環課表」分段的根：多組循環清單，逐組啟用／停用、命名、刪除；點進去編輯內容。
/// 不自帶 NavigationStack：由動作庫 tab 共用的 NavigationStack 承載（見 App/RootView 的 LibraryTabView）。
public struct RotationListView: View {
    @Bindable private var viewModel: RotationListViewModel
    private let makeEditor: @MainActor (UUID) -> RotationEditorViewModel
    @State private var creating = false
    @State private var renaming: Rotation?

    public init(
        viewModel: RotationListViewModel,
        makeEditor: @escaping @MainActor (UUID) -> RotationEditorViewModel
    ) {
        self.viewModel = viewModel
        self.makeEditor = makeEditor
    }

    public var body: some View {
        List {
            ForEach(viewModel.rotations) { rotation in
                row(rotation)
            }
        }
        .navigationDestination(for: UUID.self) { id in
            RotationEditorView(viewModel: makeEditor(id))
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creating = true
                } label: {
                    Label { localText("rotation.list.new") } icon: { Image(systemName: "plus") }
                }
            }
        }
        .overlay {
            if viewModel.rotations.isEmpty {
                ContentUnavailableView {
                    Label { localText("rotation.empty") } icon: { Image(systemName: "arrow.triangle.2.circlepath") }
                } description: {
                    localText("rotation.empty.hint")
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $creating) {
            RotationNameFormView(titleKey: "rotation.list.new") { name in
                await viewModel.create(name: name)
            }
        }
        .sheet(item: $renaming) { rotation in
            RotationNameFormView(titleKey: "rotation.rename", name: rotation.name) { name in
                await viewModel.rename(id: rotation.id, name: name)
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

    private func row(_ rotation: Rotation) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { rotation.isActive },
                set: { on in Task { await viewModel.setActive(id: rotation.id, on) } }
            )) {
                localText("rotation.active")
            }
            .labelsHidden()

            NavigationLink(value: rotation.id) {
                VStack(alignment: .leading, spacing: 4) {
                    // 循環課表名是使用者資料（verbatim）
                    Text(verbatim: rotation.name).font(.headline)
                    subtitle(rotation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.delete(id: rotation.id) }
            } label: {
                localText("plan.delete")
            }
            Button {
                renaming = rotation
            } label: {
                localText("rotation.rename")
            }
            .tint(.gray)
        }
    }

    @ViewBuilder
    private func subtitle(_ rotation: Rotation) -> some View {
        if rotation.workouts.isEmpty {
            localText("rotation.workout.empty")
        } else if !rotation.isActive {
            localText("rotation.paused")
        } else if let current = rotation.current {
            HStack(spacing: 4) {
                localText("rotation.turnPrefix")
                Text(verbatim: current.name)
            }
        }
    }
}
