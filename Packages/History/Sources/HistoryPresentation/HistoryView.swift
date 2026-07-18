import HistoryDomain
import SharedKernel
import SwiftUI

public struct HistoryView: View {
    @Bindable private var viewModel: HistoryViewModel
    @Environment(\.locale) private var locale

    public init(viewModel: HistoryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.mode {
                case .byDate: byDate
                case .byExercise: byExercise
                }
            }
            .navigationTitle(localText("history.title"))
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker(selection: $viewModel.mode) {
                    localText("history.byDate").tag(HistoryMode.byDate)
                    localText("history.byExercise").tag(HistoryMode.byExercise)
                } label: {
                    localText("history.viewBy")
                }
                .pickerStyle(.segmented)
                .padding()
                .background(.bar)
            }
            .task { await viewModel.load() }
            .alert(
                localText("history.error"),
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.dismissError() } }
                )
            ) {
                Button(role: .cancel) {} label: { localText("history.ok") }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - 按日期

    @ViewBuilder private var byDate: some View {
        if viewModel.workouts.isEmpty {
            ContentUnavailableView {
                Label { localText("history.empty") } icon: { Image(systemName: "calendar") }
            } description: {
                localText("history.empty.hint")
            }
        } else {
            List(viewModel.workouts) { summary in
                NavigationLink {
                    WorkoutDetailView(summary: summary, makeViewModel: viewModel.makeDetailViewModel(for: summary.id))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(HistoryFormatting.dayLabel(summary.day, locale: locale)).font(.headline)
                        HStack(spacing: 6) {
                            if let minutes = summary.durationMinutes {
                                localText("history.minutesShort \(minutes)")
                            }
                            localText("history.setsCount \(summary.totalSets)")
                            localText("history.exerciseCount \(summary.exerciseCount)")
                            if !HistoryFormatting.feeling(summary.overallFeeling).isEmpty {
                                Text(HistoryFormatting.feeling(summary.overallFeeling))
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 按動作

    @ViewBuilder private var byExercise: some View {
        if viewModel.exerciseOptions.isEmpty {
            ContentUnavailableView {
                Label { localText("history.empty") } icon: { Image(systemName: "chart.line.uptrend.xyaxis") }
            } description: {
                localText("history.empty.hint")
            }
        } else {
            List {
                Section {
                    Picker(selection: $viewModel.selectedExerciseId) {
                        ForEach(viewModel.exerciseOptions) { option in
                            // 動作名是 DB 資料（verbatim）
                            Text(verbatim: option.name).tag(Optional(option.id))
                        }
                    } label: {
                        localText("history.exercise")
                    }
                    HStack {
                        localText("history.trained")
                        Spacer()
                        localText("history.timesCount \(viewModel.selectedExerciseSessionCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(viewModel.sessions) { session in
                        HStack {
                            Text(HistoryFormatting.dayLabel(session.day, locale: locale))
                                .font(.subheadline)
                            Spacer()
                            Text(HistoryFormatting.summary(of: session.sets))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }
}
