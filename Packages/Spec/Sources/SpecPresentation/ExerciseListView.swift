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
                        Button("刪除", role: .destructive) {
                            Task { await viewModel.remove(id: exercise.id) }
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "搜尋動作")
            .navigationTitle("動作庫")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingTarget = .create
                    } label: {
                        Label("新增動作", systemImage: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                filterChips
            }
            .overlay {
                if viewModel.visibleExercises.isEmpty {
                    ContentUnavailableView(
                        "還沒有動作",
                        systemImage: "dumbbell",
                        description: Text("點右上角＋建立第一個動作")
                    )
                }
            }
            .task {
                await viewModel.load()
            }
            .sheet(item: $editingTarget) { target in
                ExerciseFormView(target: target) { name, muscleGroup, description in
                    switch target {
                    case .create:
                        await viewModel.add(name: name, muscleGroup: muscleGroup, description: description)
                    case .edit(let exercise):
                        await viewModel.edit(id: exercise.id, name: name, muscleGroup: muscleGroup, description: description)
                    }
                }
            }
            .alert(
                "出錯了",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.dismissError() } }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func row(for exercise: Exercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                if let description = exercise.description {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(exercise.muscleGroup.displayName)
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
                chip(title: "全部", isSelected: viewModel.filter == nil) {
                    await viewModel.setFilter(nil)
                }
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    chip(title: group.displayName, isSelected: viewModel.filter == group) {
                        await viewModel.setFilter(group)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
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
