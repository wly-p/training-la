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
    @State private var rotationListViewModel: RotationListViewModel
    @State private var programListViewModel: ProgramListViewModel
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
        _rotationListViewModel = State(initialValue: dependencies.makeRotationListViewModel())
        _programListViewModel = State(initialValue: dependencies.makeProgramListViewModel())
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
                templateViewModel: templateListViewModel,
                rotationListViewModel: rotationListViewModel,
                makeRotationEditor: dependencies.makeRotationEditorViewModel,
                programListViewModel: programListViewModel,
                makeProgramEditor: dependencies.makeProgramEditorViewModel
            )
            .tabItem { Label("tab.exercises", systemImage: "books.vertical") }
            .tag(1)
            PlanScheduleView(viewModel: planScheduleViewModel)
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

/// 動作庫 tab：共用單一 NavigationStack，頂部分段切換「動作／課表範本／循環課表」三種訓練素材。
/// 子頁不各自帶 NavigationStack，它們的 toolbar（＋／編輯）會掛到這層共用的 nav bar（情境化）。
private struct LibraryTabView: View {
    let exerciseViewModel: ExerciseListViewModel
    let templateViewModel: TemplateListViewModel
    let rotationListViewModel: RotationListViewModel
    let makeRotationEditor: @MainActor (UUID) -> RotationEditorViewModel
    let programListViewModel: ProgramListViewModel
    let makeProgramEditor: @MainActor (UUID) -> ProgramEditorViewModel
    @State private var mode = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $mode) {
                    Text("library.exercises").tag(0)
                    Text("library.templates").tag(1)
                    Text("library.rotation").tag(2)
                    Text("library.program").tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch mode {
                case 0: ExerciseListView(viewModel: exerciseViewModel)
                case 1: TemplateListView(viewModel: templateViewModel)
                case 2: RotationListView(viewModel: rotationListViewModel, makeEditor: makeRotationEditor)
                default: ProgramListView(viewModel: programListViewModel, makeEditor: makeProgramEditor)
                }
            }
            .navigationTitle("tab.exercises")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
