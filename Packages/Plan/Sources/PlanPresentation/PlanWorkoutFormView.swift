import PlanDomain
import SharedKernel
import SwiftUI

/// 當日排課表單。`readOnly`（已完成排課）時全欄位鎖住、僅供檢視。
struct PlanWorkoutFormView: View {
    let target: PlanFormTarget
    let catalog: [PlanCatalogExercise]
    let readOnly: Bool
    let onSubmit: (String?, DayDate, [ExerciseTargetDraft]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var date: Date
    @State private var drafts: [ExerciseTargetDraft]

    init(
        target: PlanFormTarget,
        catalog: [PlanCatalogExercise],
        readOnly: Bool = false,
        onSubmit: @escaping (String?, DayDate, [ExerciseTargetDraft]) async -> Void
    ) {
        self.target = target
        self.catalog = catalog
        self.readOnly = readOnly
        self.onSubmit = onSubmit
        switch target {
        case .create(let day):
            _name = State(initialValue: "")
            _date = State(initialValue: day.asDate)
            _drafts = State(initialValue: [])
        case .edit(let plan):
            _name = State(initialValue: plan.name ?? "")
            _date = State(initialValue: plan.date.asDate)
            _drafts = State(initialValue: draftsFromBlocks(plan.blocks))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if readOnly {
                    Section {
                        Label { localText("plan.readOnly.hint") } icon: { Image(systemName: "checkmark.circle.fill") }
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    TextField("", text: $name, prompt: localText("plan.name.placeholder"))
                    DatePicker(selection: $date, displayedComponents: .date) {
                        localText("plan.date")
                    }
                }
                .disabled(readOnly)

                ExerciseDraftsEditor(drafts: $drafts, catalog: catalog, readOnly: readOnly)
            }
            .navigationTitle(localText(navTitle))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText(readOnly ? "plan.close" : "plan.cancel") }
                }
                if !readOnly {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task {
                                await onSubmit(name.isEmpty ? nil : name, DayDate(date), drafts)
                                dismiss()
                            }
                        } label: {
                            localText("plan.save")
                        }
                        .disabled(drafts.isEmpty)
                    }
                }
            }
        }
    }

    private var navTitle: LocalizedStringKey {
        if readOnly { return "plan.view" }
        if case .create = target { return "plan.new" }
        return "plan.edit"
    }
}
