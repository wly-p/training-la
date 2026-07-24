import SwiftUI

/// 循環課表命名表單（建立 / 重新命名共用）：只有一個名稱欄位。
struct RotationNameFormView: View {
    let titleKey: LocalizedStringKey
    let onSubmit: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(titleKey: LocalizedStringKey, name: String = "", onSubmit: @escaping (String) async -> Void) {
        self.titleKey = titleKey
        self.onSubmit = onSubmit
        _name = State(initialValue: name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("", text: $name, prompt: localText("rotation.name.placeholder"))
                }
            }
            .navigationTitle(localText(titleKey))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("plan.cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await onSubmit(name)
                            dismiss()
                        }
                    } label: {
                        localText("plan.save")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
