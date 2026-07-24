import PlanDomain
import SharedKernel
import SwiftUI

/// 編輯單一 workout（名稱 + 動作目標）——環尋循環的一張、或其他需要「名稱＋drafts」的地方共用。
struct WorkoutSpecFormView: View {
    let titleKey: LocalizedStringKey
    let catalog: [PlanCatalogExercise]
    /// 可帶入的課表範本（copy 快照來源）；空＝不顯示「從範本帶入」。
    let templates: [WorkoutTemplate]
    let onSubmit: (String, [ExerciseTargetDraft]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var drafts: [ExerciseTargetDraft]
    @State private var pickingTemplate = false

    init(
        titleKey: LocalizedStringKey,
        name: String = "",
        drafts: [ExerciseTargetDraft] = [],
        catalog: [PlanCatalogExercise],
        templates: [WorkoutTemplate] = [],
        onSubmit: @escaping (String, [ExerciseTargetDraft]) -> Void
    ) {
        self.titleKey = titleKey
        self.catalog = catalog
        self.templates = templates
        self.onSubmit = onSubmit
        _name = State(initialValue: name)
        _drafts = State(initialValue: drafts)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("", text: $name, prompt: localText("rotation.workout.name.placeholder"))
                    if !templates.isEmpty {
                        Button {
                            pickingTemplate = true
                        } label: {
                            Label { localText("workoutSpec.fromTemplate") } icon: { Image(systemName: "square.stack.3d.up") }
                        }
                    }
                }
                ExerciseDraftsEditor(drafts: $drafts, catalog: catalog)
            }
            .navigationTitle(localText(titleKey))
            .sheet(isPresented: $pickingTemplate) {
                WorkoutSpecTemplatePicker(templates: templates) { template in
                    importTemplate(template)
                }
            }
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

    /// 從範本帶入＝copy 快照：填入動作目標；名稱空白時一併帶入範本名。
    private func importTemplate(_ template: WorkoutTemplate) {
        drafts = draftsFromBlocks(template.blocks)
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = template.name
        }
    }
}

/// 選一份課表範本帶入（copy）。
private struct WorkoutSpecTemplatePicker: View {
    let templates: [WorkoutTemplate]
    let onSelect: (WorkoutTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(templates) { template in
                Button {
                    onSelect(template)
                    dismiss()
                } label: {
                    // 範本名是使用者資料（verbatim）
                    Text(verbatim: template.name)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(localText("workoutSpec.fromTemplate"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("plan.cancel") }
                }
            }
        }
    }
}
