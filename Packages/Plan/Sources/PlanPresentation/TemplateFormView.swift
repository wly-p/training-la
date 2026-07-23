import PlanDomain
import SharedKernel
import SwiftUI

/// 課表範本表單：名稱 + 動作目標（無日期、無狀態）。
struct TemplateFormView: View {
    enum Target {
        case create
        case edit(WorkoutTemplate)
    }

    let target: Target
    let catalog: [PlanCatalogExercise]
    let onSubmit: (String, [ExerciseTargetDraft]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var drafts: [ExerciseTargetDraft]

    init(
        target: Target,
        catalog: [PlanCatalogExercise],
        onSubmit: @escaping (String, [ExerciseTargetDraft]) async -> Void
    ) {
        self.target = target
        self.catalog = catalog
        self.onSubmit = onSubmit
        switch target {
        case .create:
            _name = State(initialValue: "")
            _drafts = State(initialValue: [])
        case .edit(let template):
            _name = State(initialValue: template.name)
            _drafts = State(initialValue: draftsFromBlocks(template.blocks))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("", text: $name, prompt: localText("template.name.placeholder"))
                }
                ExerciseDraftsEditor(drafts: $drafts, catalog: catalog)
            }
            .navigationTitle(localText(isCreating ? "template.new" : "template.edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("plan.cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await onSubmit(name, drafts)
                            dismiss()
                        }
                    } label: {
                        localText("plan.save")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || drafts.isEmpty)
                }
            }
        }
    }

    private var isCreating: Bool {
        if case .create = target { return true }
        return false
    }
}
