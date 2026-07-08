import SharedKernel
import SpecDomain
import SwiftUI

struct ExerciseFormView: View {
    let target: FormTarget
    let onSubmit: (String, MuscleGroup, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var muscleGroup: MuscleGroup
    @State private var descriptionText: String

    init(target: FormTarget, onSubmit: @escaping (String, MuscleGroup, String?) async -> Void) {
        self.target = target
        self.onSubmit = onSubmit
        switch target {
        case .create:
            _name = State(initialValue: "")
            _muscleGroup = State(initialValue: .chest)
            _descriptionText = State(initialValue: "")
        case .edit(let exercise):
            _name = State(initialValue: exercise.name)
            _muscleGroup = State(initialValue: exercise.muscleGroup)
            _descriptionText = State(initialValue: exercise.description ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("名稱（例：臥推）", text: $name)
                Picker("肌群", selection: $muscleGroup) {
                    ForEach(MuscleGroup.allCases, id: \.self) { group in
                        Text(group.displayName).tag(group)
                    }
                }
                TextField("備註（可留空）", text: $descriptionText, axis: .vertical)
            }
            .navigationTitle(isCreating ? "新增動作" : "編輯動作")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        Task {
                            await onSubmit(name, muscleGroup, descriptionText.isEmpty ? nil : descriptionText)
                            dismiss()
                        }
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
