import SharedKernel
import SpecDomain
import SwiftUI

public struct ExerciseListView: View {
    @Bindable private var viewModel: ExerciseListViewModel
    @State private var editingTarget: FormTarget?

    public init(viewModel: ExerciseListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.visibleExercises) { exercise in
                    Button {
                        editingTarget = .edit(exercise)
                    } label: {
                        row(for: exercise)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.remove(id: exercise.id) }
                        } label: {
                            localText("spec.delete")
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: localText("spec.searchExercises"))
            .navigationTitle(localText("spec.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingTarget = .create
                    } label: {
                        Label { localText("spec.new") } icon: { Image(systemName: "plus") }
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                filterChips
            }
            .overlay {
                if viewModel.visibleExercises.isEmpty {
                    ContentUnavailableView {
                        Label { localText("spec.empty") } icon: { Image(systemName: "dumbbell") }
                    } description: {
                        localText("spec.empty.hint")
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .sheet(item: $editingTarget) { target in
                ExerciseFormView(target: target) { name, muscleGroup, equipment, description in
                    switch target {
                    case .create:
                        await viewModel.add(name: name, muscleGroup: muscleGroup, equipment: equipment, description: description)
                    case .edit(let exercise):
                        await viewModel.edit(id: exercise.id, name: name, muscleGroup: muscleGroup, equipment: equipment, description: description)
                    }
                }
            }
            .alert(
                localText("spec.error"),
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.dismissError() } }
                )
            ) {
                Button(role: .cancel) {} label: { localText("spec.ok") }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func row(for exercise: Exercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // 動作名、器材、備註都是 DB / enum 資料（verbatim）
                Text(verbatim: exercise.name)
                Text(verbatim: exercise.equipment.displayName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let description = exercise.description {
                    Text(verbatim: description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(verbatim: exercise.muscleGroup.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
        .contentShape(Rectangle())
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 「全部」本地化；肌群是 enum 資料（verbatim，不做）
                chip(title: localText("spec.all"), isSelected: viewModel.filter == nil) {
                    await viewModel.setFilter(nil)
                }
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    chip(title: Text(verbatim: group.displayName), isSelected: viewModel.filter == group) {
                        await viewModel.setFilter(group)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func chip(title: Text, isSelected: Bool, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            title
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

enum FormTarget: Identifiable {
    case create
    case edit(Exercise)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let exercise): exercise.id.uuidString
        }
    }
}
