import DesignSystem
import HistoryDomain
import SharedKernel
import SwiftUI

/// 歷史分頁（設計稿 7b）：依日期（月份分組清單）／依動作（清單→單一動作趨勢圖，見
/// `ExerciseHistoryView`——清單頁本身不放圖表）。
public struct HistoryView: View {
    @Bindable private var viewModel: HistoryViewModel
    @Environment(\.locale) private var locale

    public init(viewModel: HistoryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PageHeader(localText("history.title"))
                    TLSegmentedControl(
                        selection: $viewModel.mode,
                        options: [
                            .init(.byDate, localText("history.byDate")),
                            .init(.byExercise, localText("history.byExercise")),
                        ]
                    )
                    .padding(.top, TLSpace.gapM)

                    Group {
                        switch viewModel.mode {
                        case .byDate: byDate
                        case .byExercise: byExercise
                        }
                    }
                    .padding(.top, TLSpace.section)
                }
                .padding(.horizontal, TLSpace.page)
                .padding(.bottom, 40)
            }
            .background(TLColor.bg.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(for: UUID.self) { exerciseId in
                if let option = viewModel.exerciseOptions.first(where: { $0.id == exerciseId }) {
                    ExerciseHistoryView(option: option, loadSessions: { await viewModel.sessions(for: exerciseId) })
                }
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

    private var freeTrainingLabel: String { localString("history.freeTraining", locale) }

    private var monthGroups: [(key: MonthKey, workouts: [HistoryWorkoutSummary])] {
        let filtered = viewModel.filteredWorkouts(freeTrainingLabel: freeTrainingLabel)
        let grouped = Dictionary(grouping: filtered) { MonthKey(year: $0.day.year, month: $0.day.month) }
        return grouped.sorted { $0.key > $1.key }.map { ($0.key, $0.value) }
    }

    @ViewBuilder private var byDate: some View {
        if viewModel.workouts.isEmpty {
            EmptyState(
                systemImage: "calendar",
                title: localString("history.empty", locale),
                message: localString("history.empty.hint", locale)
            )
        } else {
            VStack(alignment: .leading, spacing: TLSpace.section) {
                TLSearchField(text: $viewModel.searchText,
                              placeholder: localText("history.search.placeholder"),
                              identifier: "history.search")
                ForEach(monthGroups, id: \.key) { group in
                    monthSection(group.key, group.workouts)
                }
            }
        }
    }

    private func monthSection(_ key: MonthKey, _ workouts: [HistoryWorkoutSummary]) -> some View {
        let totalMinutes = workouts.compactMap(\.durationMinutes).reduce(0, +)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(HistoryFormatting.monthLabel(month: key.month, locale: locale) + " · ")
                    + localText("history.monthCount \(workouts.count)")
                Spacer()
                localText("history.monthDuration \(totalMinutes / 60) \(totalMinutes % 60)")
            }
            .font(TLFont.zh(TLFont.kicker, .semibold))
            .tracking(TLFont.kickerTracking)
            .foregroundStyle(TLColor.neutral500)
            .padding(.bottom, 8)
            TLGroup {
                ForEach(workouts) { summary in
                    workoutRow(summary)
                        .accessibilityIdentifier("history.workoutRow")
                }
            }
        }
    }

    private func workoutRow(_ summary: HistoryWorkoutSummary) -> some View {
        NavigationLink {
            WorkoutDetailView(summary: summary, makeViewModel: viewModel.makeDetailViewModel(for: summary.id))
        } label: {
            ListRow(
                title: summary.name.map { Text(verbatim: $0) } ?? Text(verbatim: freeTrainingLabel),
                subtitle: Text(daySummaryLine(summary)),
                showChevron: true,
                leading: {
                    VStack(spacing: 1) {
                        Text(verbatim: "\(summary.day.day)")
                            .font(TLFont.display(19))
                            .foregroundStyle(TLColor.text)
                        Text(verbatim: HistoryFormatting.weekdayAbbrev(summary.day, locale: locale))
                            .font(TLFont.zh(9.5, .medium))
                            .foregroundStyle(TLColor.neutral500)
                    }
                    .frame(width: 40)
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func daySummaryLine(_ summary: HistoryWorkoutSummary) -> String {
        var parts = [String(format: localString("history.exerciseCount %lld", locale), summary.exerciseCount)]
        parts.append(String(format: localString("history.setsCount %lld", locale), summary.totalSets))
        if let minutes = summary.durationMinutes {
            parts.append(String(format: localString("history.minutesShort %lld", locale), minutes))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - 按動作

    @ViewBuilder private var byExercise: some View {
        if viewModel.exerciseOptions.isEmpty {
            EmptyState(
                systemImage: "chart.line.uptrend.xyaxis",
                title: localString("history.empty", locale),
                message: localString("history.empty.hint", locale)
            )
        } else {
            TLGroup {
                ForEach(viewModel.exerciseOptions) { option in
                    NavigationLink(value: option.id) {
                        ListRow(
                            title: Text(verbatim: option.name),
                            subtitle: Text(verbatim: option.muscleGroup.displayName(locale)),
                            showChevron: true,
                            leading: { CircleBadge(muscle: option.muscleGroup.badgeText(locale)) }
                        )
                    }
                }
            }
        }
    }
}

private struct MonthKey: Hashable, Comparable {
    let year: Int
    let month: Int
    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool { (lhs.year, lhs.month) < (rhs.year, rhs.month) }
}
