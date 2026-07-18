import HistoryPresentation
import PlanPresentation
import SettingsPresentation
import SharedKernel
import SpecPresentation
import SwiftUI
import TrainingPresentation

struct RootView: View {
    private let dependencies: AppDependencies
    @State private var exerciseListViewModel: ExerciseListViewModel
    @State private var trainingHomeViewModel: TrainingHomeViewModel
    @State private var historyViewModel: HistoryViewModel
    @State private var planScheduleViewModel: PlanScheduleViewModel
    @State private var settingsViewModel: SettingsViewModel

    init(dependencies: AppDependencies, onEraseAll: @escaping @MainActor () -> Void) {
        self.dependencies = dependencies
        _exerciseListViewModel = State(initialValue: dependencies.makeExerciseListViewModel())
        _trainingHomeViewModel = State(initialValue: dependencies.makeTrainingHomeViewModel())
        _historyViewModel = State(initialValue: dependencies.makeHistoryViewModel())
        _planScheduleViewModel = State(initialValue: dependencies.makePlanScheduleViewModel())
        _settingsViewModel = State(initialValue: dependencies.makeSettingsViewModel(onEraseAll))
    }

    var body: some View {
        TabView {
            TrainingHomeView(
                viewModel: trainingHomeViewModel,
                makeActiveWorkoutViewModel: dependencies.makeActiveWorkoutViewModel
            )
            // tab 文字走 App target 自帶的 Localizable.xcstrings（在 main bundle，Label 預設查 main，
            // 不需 bundle: 參數）；隨根部注入的 \.locale 即時切換。
            .tabItem { Label("tab.training", systemImage: "figure.strengthtraining.traditional") }
            ExerciseListView(viewModel: exerciseListViewModel)
                .tabItem { Label("tab.exercises", systemImage: "books.vertical") }
            PlanScheduleView(viewModel: planScheduleViewModel)
                .tabItem { Label("tab.plan", systemImage: "calendar") }
            HistoryView(viewModel: historyViewModel)
                .tabItem { Label("tab.history", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView(
                viewModel: settingsViewModel,
                appVersion: AppVersion.displayString(infoDictionary: Bundle.main.infoDictionary ?? [:])
            )
            .tabItem { Label("tab.settings", systemImage: "gearshape") }
        }
        // 主題套在根部：設定 tab 一改，整個 App 立即換色
        .preferredColorScheme(settingsViewModel.theme.colorScheme)
        // 語言同樣套在根部：注入 \.locale 讓所有 Text(key, bundle:) 依此語言查表，切換即時重繪
        .environment(\.locale, settingsViewModel.language.locale)
    }
}
