import PlanDomain
import SharedKernel
import SwiftUI

/// 編輯單一 workout（名稱 + 動作目標）——環尋循環的一張、或其他需要「名稱＋drafts」的地方共用。
struct WorkoutSpecFormView: View {
    let titleKey: LocalizedStringKey
    let catalog: [PlanCatalogExercise]
    let onSubmit: (String, [ExerciseTargetDraft]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var drafts: [ExerciseTargetDraft]

    init(
        titleKey: LocalizedStringKey,
        name: String = "",
        drafts: [ExerciseTargetDraft] = [],
        catalog: [PlanCatalogExercise],
        onSubmit: @escaping (String, [ExerciseTargetDraft]) -> Void
    ) {
        self.titleKey = titleKey
        self.catalog = catalog
        self.onSubmit = onSubmit
        _name = State(initialValue: name)
        _drafts = State(initialValue: drafts)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("", text: $name, prompt: localText("rotation.workout.name.placeholder"))
                }
                ExerciseDraftsEditor(drafts: $drafts, catalog: catalog)
            }
            .navigationTitle(localText(titleKey))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("plan.cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSubmit(name, drafts)
                        dismiss()
                    } label: {
                        localText("plan.save")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || drafts.isEmpty)
                }
            }
        }
    }
}
