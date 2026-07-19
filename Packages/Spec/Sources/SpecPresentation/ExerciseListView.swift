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
                // chips 放進 List 當 Section header（不是 .safeAreaInset）：List 的 section header
                // 本來就有「捲動時釘在頂端」的原生行為，效果跟 safeAreaInset 一樣；差別在於它現在是
                // List 自己 scroll view 的一部分，不是另一個跟 List 競爭的獨立 ScrollView——
                // 後者會干擾 NavigationStack 大標題的捲動偵測，導致大標題視覺上空白（見對應 bug ticket）。
                Section {
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
                } header: {
                    filterChips
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
