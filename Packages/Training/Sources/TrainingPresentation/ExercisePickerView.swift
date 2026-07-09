import SharedKernel
import SwiftUI
import TrainingDomain

/// 從動作庫挑動作（資料來自 ExerciseCatalog port，不認識 Spec package）。
struct ExercisePickerView: View {
    let catalog: [CatalogExercise]
    let onSelect: (CatalogExercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var visible: [CatalogExercise] {
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
                        Text(exercise.name)
                        Spacer()
                        Text(exercise.muscleGroup.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "搜尋動作")
            .navigationTitle("選擇動作")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .overlay {
                if catalog.isEmpty {
                    ContentUnavailableView(
                        "動作庫是空的",
                        systemImage: "books.vertical",
                        description: Text("先到「動作庫」分頁建立動作")
                    )
                }
            }
        }
    }
}
