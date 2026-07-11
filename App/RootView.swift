import HistoryPresentation
import PlanPresentation
import SettingsPresentation
import SharedKernel
import SpecPresentation
import SwiftUI
import TrainingPresentation

struct RootView: View {
    private let dependencies: AppDependencies
    private let environment: AppEnvironment
    @State private var exerciseListViewModel: ExerciseListViewModel
    @State private var trainingHomeViewModel: TrainingHomeViewModel
    @State private var historyViewModel: HistoryViewModel
    @State private var planScheduleViewModel: PlanScheduleViewModel
    @State private var settingsViewModel: SettingsViewModel

    init(dependencies: AppDependencies, environment: AppEnvironment) {
        self.dependencies = dependencies
        self.environment = environment
        _exerciseListViewModel = State(initialValue: dependencies.makeExerciseListViewModel())
        _trainingHomeViewModel = State(initialValue: dependencies.makeTrainingHomeViewModel())
        _historyViewModel = State(initialValue: dependencies.makeHistoryViewModel())
        _planScheduleViewModel = State(initialValue: dependencies.makePlanScheduleViewModel())
        _settingsViewModel = State(initialValue: dependencies.makeSettingsViewModel())
    }

    var body: some View {
        TabView {
            TrainingHomeView(
                viewModel: trainingHomeViewModel,
                makeActiveWorkoutViewModel: dependencies.makeActiveWorkoutViewModel
            )
            .tabItem { Label("訓練", systemImage: "figure.strengthtraining.traditional") }
            ExerciseListView(viewModel: exerciseListViewModel)
                .tabItem { Label("動作庫", systemImage: "books.vertical") }
            PlanScheduleView(viewModel: planScheduleViewModel)
                .tabItem { Label("課表", systemImage: "calendar") }
            HistoryView(viewModel: historyViewModel)
                .tabItem { Label("歷史", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView(viewModel: settingsViewModel, environmentBadge: environment.badge)
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        // 主題套在根部：設定 tab 一改，整個 App 立即換色
        .preferredColorScheme(settingsViewModel.theme.colorScheme)
    }
}
