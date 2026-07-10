import SwiftUI

struct FinishWorkoutSheet: View {
    let durationMinutes: Int
    let totalSets: Int
    let onFinish: (Int?, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var feeling: Int?
    @State private var note = ""

    private let feelingOptions: [(value: Int, emoji: String)] = [
        (1, "😫"), (2, "😕"), (3, "😐"), (4, "🙂"), (5, "💪"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("\(durationMinutes) 分鐘", systemImage: "clock")
                        Spacer()
                        Label("共 \(totalSets) 組", systemImage: "checklist")
                    }
                    .foregroundStyle(.secondary)
                }
                Section("感受如何？") {
                    HStack(spacing: 0) {
                        ForEach(feelingOptions, id: \.value) { option in
                            Button {
                                feeling = feeling == option.value ? nil : option.value
                            } label: {
                                Text(option.emoji)
                                    .font(.system(size: 30))
                                    .frame(maxWidth: .infinity)
                                    .opacity(feeling == nil || feeling == option.value ? 1 : 0.3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("備註") {
                    TextField("今天狀態如何…", text: $note, axis: .vertical)
                }
            }
            .navigationTitle("本次訓練")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("繼續訓練") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存並結束") {
                        Task {
                            await onFinish(feeling, note)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
