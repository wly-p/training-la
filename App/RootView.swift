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
    @State private var templateListViewModel: TemplateListViewModel
    @State private var trainingHomeViewModel: TrainingHomeViewModel
    @State private var historyViewModel: HistoryViewModel
    @State private var planScheduleViewModel: PlanScheduleViewModel
    @State private var settingsViewModel: SettingsViewModel
    /// 目前分頁；放在被 `.id(language)` 重建的 TabView 外層，切語言重建後才能留在原分頁。
    @State private var selection = 0

    init(dependencies: AppDependencies, onEraseAll: @escaping @MainActor () -> Void) {
        self.dependencies = dependencies
        _exerciseListViewModel = State(initialValue: dependencies.makeExerciseListViewModel())
        _templateListViewModel = State(initialValue: dependencies.makeTemplateListViewModel())
        _trainingHomeViewModel = State(initialValue: dependencies.makeTrainingHomeViewModel())
        _historyViewModel = State(initialValue: dependencies.makeHistoryViewModel())
        _planScheduleViewModel = State(initialValue: dependencies.makePlanScheduleViewModel())
        _settingsViewModel = State(initialValue: dependencies.makeSettingsViewModel(onEraseAll))
    }

    var body: some View {
        TabView(selection: $selection) {
            TrainingHomeView(
                viewModel: trainingHomeViewModel,
                makeActiveWorkoutViewModel: dependencies.makeActiveWorkoutViewModel
            )
            // tab 文字走 App target 自帶的 Localizable.xcstrings（在 main bundle，Label 預設查 main，
            // 不需 bundle: 參數）；隨根部注入的 \.locale 即時切換。
            .tabItem { Label("tab.training", systemImage: "figure.strengthtraining.traditional") }
            .tag(0)
            LibraryTabView(
                exerciseViewModel: exerciseListViewModel,
                templateViewModel: templateListViewModel
            )
            .tabItem { Label("tab.exercises", systemImage: "books.vertical") }
            .tag(1)
            PlanScheduleView(
                viewModel: planScheduleViewModel,
                makeRotationEditor: dependencies.makeRotationEditorViewModel
            )
            .tabItem { Label("tab.plan", systemImage: "calendar") }
            .tag(2)
            HistoryView(viewModel: historyViewModel)
                .tabItem { Label("tab.history", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(3)
            SettingsView(
                viewModel: settingsViewModel,
                appVersion: AppVersion.displayString(infoDictionary: Bundle.main.infoDictionary ?? [:])
            )
            .tabItem { Label("tab.settings", systemImage: "gearshape") }
            .tag(4)
        }
        // 主題套在根部：設定 tab 一改，整個 App 立即換色
        .preferredColorScheme(settingsViewModel.theme.colorScheme)
        // 語言套在根部：注入 \.locale 讓所有 Text(key, bundle:) 依此語言查表，body 內文字即時重繪。
        .environment(\.locale, settingsViewModel.language.locale)
        // navigationTitle 橋接 UIKit navigationItem、建立時解析一次就快取，不隨 \.locale 重解析；
        // 切語言時用 .id 強制整個 TabView 子樹重建，標題以新語言重產（同「刪除所有資料」的 resetToken 手法）。
        // selection 綁在外層 @State，重建後留在原分頁。
        .id(settingsViewModel.language)
    }
}

/// 動作庫 tab：以分段切換「動作」與「課表範本」兩種可重複使用的訓練素材。
private struct LibraryTabView: View {
    let exerciseViewModel: ExerciseListViewModel
    let templateViewModel: TemplateListViewModel
    @State private var mode = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                Text("library.exercises").tag(0)
                Text("library.templates").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.top, 8)

            if mode == 0 {
                ExerciseListView(viewModel: exerciseViewModel)
            } else {
                TemplateListView(viewModel: templateViewModel)
            }
        }
    }
}
