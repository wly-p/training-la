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
                        // 動作名與肌群都是 DB / enum 資料，不本地化（verbatim）
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
            .searchable(text: $searchText, prompt: localText("training.searchExercises"))
            .navigationTitle(localText("training.chooseExercise"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("training.cancel") }
                }
            }
            .overlay {
                if catalog.isEmpty {
                    ContentUnavailableView {
                        Label {
                            localText("training.emptyLibrary")
                        } icon: {
                            Image(systemName: "books.vertical")
                        }
                    } description: {
                        localText("training.emptyLibrary.hint")
                    }
                }
            }
        }
    }
}
