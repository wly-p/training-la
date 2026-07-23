import SharedKernel
import SpecDomain
import SwiftUI

struct ExerciseFormView: View {
    let target: FormTarget
    let onSubmit: (String, MuscleGroup, Equipment, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var muscleGroup: MuscleGroup
    @State private var equipment: Equipment
    @State private var descriptionText: String

    init(target: FormTarget, onSubmit: @escaping (String, MuscleGroup, Equipment, String?) async -> Void) {
        self.target = target
        self.onSubmit = onSubmit
        switch target {
        case .create:
            _name = State(initialValue: "")
            _muscleGroup = State(initialValue: .chest)
            _equipment = State(initialValue: .barbell)
            _descriptionText = State(initialValue: "")
        case .edit(let exercise):
            _name = State(initialValue: exercise.name)
            _muscleGroup = State(initialValue: exercise.muscleGroup)
            _equipment = State(initialValue: exercise.equipment)
            _descriptionText = State(initialValue: exercise.description ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("", text: $name, prompt: localText("spec.name.placeholder"))
                Picker(selection: $muscleGroup) {
                    // 肌群 / 器材選項是 enum 資料（verbatim，不做）
                    ForEach(MuscleGroup.allCases, id: \.self) { group in
                        Text(verbatim: group.displayName).tag(group)
                    }
                } label: {
                    localText("spec.muscleGroup")
                }
                Picker(selection: $equipment) {
                    ForEach(Equipment.allCases, id: \.self) { item in
                        Text(verbatim: item.displayName).tag(item)
                    }
                } label: {
                    localText("spec.equipment")
                }
                TextField("", text: $descriptionText, prompt: localText("spec.notes.optional"), axis: .vertical)
            }
            .navigationTitle(isCreating ? localText("spec.new") : localText("spec.edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("spec.cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await onSubmit(name, muscleGroup, equipment, descriptionText.isEmpty ? nil : descriptionText)
                            dismiss()
                        }
                    } label: {
                        localText("spec.save")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var isCreating: Bool {
        if case .create = target { return true }
        return false
    }
}
