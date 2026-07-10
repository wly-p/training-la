import HistoryDomain
import SharedKernel
import SwiftUI

struct WorkoutDetailView: View {
    let summary: HistoryWorkoutSummary
    let load: () async -> HistoryWorkoutDetail?

    @State private var detail: HistoryWorkoutDetail?

    var body: some View {
        List {
            if let detail {
                Section {
                    HStack(spacing: 12) {
                        if let minutes = detail.summary.durationMinutes {
                            Label("\(minutes) 分鐘", systemImage: "clock")
                        }
                        Label("\(detail.summary.totalSets) 組", systemImage: "checklist")
                        if !HistoryFormatting.feeling(detail.summary.overallFeeling).isEmpty {
                            Text(HistoryFormatting.feeling(detail.summary.overallFeeling))
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    if let note = detail.note {
                        Text(note)
                    }
                }
                ForEach(detail.blocks) { block in
                    Section(block.exerciseName) {
                        ForEach(block.sets) { set in
                            HStack {
                                Text("第\(set.setIndex + 1)組")
                                    .foregroundStyle(set.status == .skipped ? .secondary : .primary)
                                Spacer()
                                if let targetWeight = set.targetWeight, let targetReps = set.targetReps {
                                    Text("目標 \(targetWeight.displayString)×\(targetReps)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Text("\(set.weight.displayString) × \(set.reps)")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(HistoryFormatting.dayLabel(summary.day))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { detail = await load() }
    }
}
