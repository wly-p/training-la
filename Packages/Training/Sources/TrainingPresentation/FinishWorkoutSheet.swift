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
                        Label {
                            localText("training.minutes \(durationMinutes)")
                        } icon: {
                            Image(systemName: "clock")
                        }
                        Spacer()
                        Label {
                            localText("training.setsTotal \(totalSets)")
                        } icon: {
                            Image(systemName: "checklist")
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                Section {
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
                } header: {
                    localText("training.howFeel")
                }
                Section {
                    TextField(
                        "",
                        text: $note,
                        prompt: localText("training.notes.placeholder"),
                        axis: .vertical
                    )
                } header: {
                    localText("training.notes")
                }
            }
            .navigationTitle(localText("training.thisWorkout"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("training.keepGoing") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await onFinish(feeling, note)
                            dismiss()
                        }
                    } label: {
                        localText("training.saveFinish")
                    }
                }
            }
        }
    }
}
