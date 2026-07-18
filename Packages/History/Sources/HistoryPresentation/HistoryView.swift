import HistoryDomain
import SharedKernel
import SwiftUI

public struct HistoryView: View {
    @Bindable private var viewModel: HistoryViewModel

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
            .navigationTitle("歷史")
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("檢視方式", selection: $viewModel.mode) {
                    Text("按日期").tag(HistoryMode.byDate)
                    Text("按動作").tag(HistoryMode.byExercise)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(.bar)
            }
            .task { await viewModel.load() }
            .alert(
                "出錯了",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.dismissError() } }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - 按日期

    @ViewBuilder private var byDate: some View {
        if viewModel.workouts.isEmpty {
            ContentUnavailableView("還沒有訓練紀錄", systemImage: "calendar", description: Text("完成一次訓練後會出現在這裡"))
        } else {
            List(viewModel.workouts) { summary in
                NavigationLink {
                    WorkoutDetailView(summary: summary, makeViewModel: viewModel.makeDetailViewModel(for: summary.id))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(HistoryFormatting.dayLabel(summary.day)).font(.headline)
                        HStack(spacing: 6) {
                            if let minutes = summary.durationMinutes {
                                Text("\(minutes)分")
                            }
                            Text("\(summary.totalSets)組")
                            Text("\(summary.exerciseCount)個動作")
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
            ContentUnavailableView("還沒有訓練紀錄", systemImage: "chart.line.uptrend.xyaxis", description: Text("完成一次訓練後會出現在這裡"))
        } else {
            List {
                Section {
                    Picker("動作", selection: $viewModel.selectedExerciseId) {
                        ForEach(viewModel.exerciseOptions) { option in
                            Text(option.name).tag(Optional(option.id))
                        }
                    }
                    HStack {
                        Text("共練過")
                        Spacer()
                        Text("\(viewModel.selectedExerciseSessionCount) 次")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    ForEach(viewModel.sessions) { session in
                        HStack {
                            Text(HistoryFormatting.dayLabel(session.day))
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
