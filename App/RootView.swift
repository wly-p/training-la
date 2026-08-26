import AbilityPresentation
import DesignSystem
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
    @State private var abilityListViewModel: AbilityListViewModel
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
        _abilityListViewModel = State(initialValue: dependencies.makeAbilityListViewModel())
    }

    var body: some View {
        TabView(selection: $selection) {
            TrainingHomeView(
                viewModel: trainingHomeViewModel,
                makeActiveWorkoutViewModel: dependencies.makeActiveWorkoutViewModel,
                openSchedule: { selection = 2 },
                openLibrary: { selection = 1 }
            )
            .tag(0)
            LibraryTabView(
                exerciseViewModel: exerciseListViewModel,
                templateViewModel: templateListViewModel,
                rotationListViewModel: rotationListViewModel,
                makeRotationDetail: dependencies.makeRotationDetailViewModel,
                programListViewModel: programListViewModel,
                makeProgramDetail: dependencies.makeProgramDetailViewModel
            )
            .tag(1)
            PlanScheduleView(viewModel: planScheduleViewModel)
                .tag(2)
            HistoryView(viewModel: historyViewModel)
                .tag(3)
            SettingsView(
                viewModel: settingsViewModel,
                appVersion: AppVersion.displayString(infoDictionary: Bundle.main.infoDictionary ?? [:]),
                // 政策頁網址由 Config.xcconfig 經 Info.plist 注入（Swift 裡不寫死網址）；
                // 語言 fragment 由設定頁依當下 app 語言現算。
                privacyPolicyBaseURL: PrivacyPolicy.baseURL(infoDictionary: Bundle.main.infoDictionary ?? [:]),
                // 能力值編輯的 ± 與刻度尺跟隨「設定 › 重量調整級距」，不寫死（handoff-15 G 節）。
                abilityDestination: {
                    AnyView(AbilityListView(
                        viewModel: abilityListViewModel,
                        weightStep: settingsViewModel.weightStep
                    ))
                }
            )
            .tag(4)
        }
        // 原生分頁列換成自訂 TLTabBar（00-overview.md 分頁列樣式：平放無膠囊底＋赭紅底線指示），
        // 隱藏原生 chrome、改用 safeAreaInset 疊自訂列——TabView 本身的分頁保留(state 不因切換重建)。
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // tab 文字走 App target 自帶的 Localizable.xcstrings（在 main bundle，Text 預設查 main，
            // 不需 bundle: 參數）；隨根部注入的 \.locale 即時切換。
            TLTabBar(selection: $selection, items: [
                .init(0, systemImage: "figure.strengthtraining.traditional",
                      label: Text("tab.training"), identifier: "training"),
                .init(1, systemImage: "books.vertical",
                      label: Text("tab.exercises"), identifier: "exercises"),
                .init(2, systemImage: "calendar",
                      label: Text("tab.plan"), identifier: "plan"),
                .init(3, systemImage: "chart.line.uptrend.xyaxis",
                      label: Text("tab.history"), identifier: "history"),
                .init(4, systemImage: "gearshape",
                      label: Text("tab.settings"), identifier: "settings"),
            ])
        }
        // 主題套在根部：設定 tab 一改，整個 App 立即換色
        .preferredColorScheme(settingsViewModel.theme.colorScheme)
        // 語言套在根部：注入 \.locale 讓所有 Text(key, bundle:) 依此語言查表，body 內文字即時重繪。
        .environment(\.locale, settingsViewModel.language.locale)
        // 重量單位同理套在根部：設定一改，全 App 的重量顯示立即換算（儲存端不變，見 Weight）。
        .environment(\.weightDisplayUnit, settingsViewModel.weightUnit)
        // navigationTitle 橋接 UIKit navigationItem、建立時解析一次就快取，不隨 \.locale 重解析；
        // 切語言時用 .id 強制整個 TabView 子樹重建，標題以新語言重產（同「刪除所有資料」的 resetToken 手法）。
        // selection 綁在外層 @State，重建後留在原分頁。
        .id(settingsViewModel.language)
    }
}

/// 動作庫 tab：共用單一 NavigationStack，頂部 PageHeader ＋自訂分段控制切換四種訓練素材
/// （動作／範本／循環／長期）。子頁不各自帶 NavigationStack，drill-in 掛到這層共用的 stack。
///
/// 頁首 44pt 圓形「+」為四個子分頁共用：點擊自增 `createToken`；當前被實例化的那個子分頁
/// 以 `.onChange(of: createToken)` 開自己的建立表單（同時只有一個子分頁存在，故只觸發當前分頁）。
/// 這樣「+」不必知道各分頁的建立細節，也不需改任何 ViewModel／DI。
private struct LibraryTabView: View {
    let exerciseViewModel: ExerciseListViewModel
    let templateViewModel: TemplateListViewModel
    let rotationListViewModel: RotationListViewModel
    let makeRotationDetail: @MainActor (UUID) -> RotationDetailViewModel
    let programListViewModel: ProgramListViewModel
    let makeProgramDetail: @MainActor (UUID) -> ProgramDetailViewModel

    private enum Mode: Hashable { case exercises, templates, rotation, program }
    @State private var mode: Mode = .exercises
    @State private var createToken = 0
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PageHeader(Text("tab.exercises")) {
                    CircleIconButton(systemImage: "plus", filled: true) { createToken += 1 }
                        .accessibilityLabel(Text("library.add"))
                        .accessibilityIdentifier("library.add")
                        // 長按 → 跨類新增選單（設計稿 10a）；短按維持直接新增當前分頁。
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.4)
                                .onEnded { _ in showAddSheet = true }
                        )
                }
                TLSegmentedControl(selection: $mode, options: [
                    .init(.exercises, Text("library.exercises")),
                    .init(.templates, Text("library.templates")),
                    .init(.rotation, Text("library.rotation")),
                    .init(.program, Text("library.program")),
                ], identifierPrefix: "library.segment")
                .padding(.horizontal, TLSpace.page)
                .padding(.top, TLSpace.gapL)
                .padding(.bottom, TLSpace.gapM)

                subtab
            }
            .background(TLColor.bg.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .sheet(isPresented: $showAddSheet) {
                AddSheet(
                    title: Text("library.add.title"),
                    subtitle: Text("library.add.subtitle"),
                    currentTag: Text("library.add.current"),
                    items: [
                        addItem(.exercises, "dumbbell", Text("library.exercises"), Text("library.add.exercise.desc")),
                        addItem(.templates, "square.stack.3d.up", Text("library.templates"), Text("library.add.template.desc")),
                        addItem(.rotation, "arrow.triangle.2.circlepath", Text("library.rotation"), Text("library.add.rotation.desc")),
                        addItem(.program, "chart.bar", Text("library.program"), Text("library.add.program.desc")),
                    ]
                )
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func addItem(_ target: Mode, _ icon: String, _ title: Text, _ subtitle: Text) -> AddSheet.Item {
        AddSheet.Item(
            id: "\(target)",
            systemImage: icon,
            title: title,
            subtitle: subtitle,
            isCurrent: mode == target,
            action: { requestCreate(target) }
        )
    }

    /// 選單選了某類：關選單 → 切到該分頁 → 觸發它的建立表單。
    /// 切分頁後子分頁才重建，故延一拍再 bump token（onChange 只在已掛載時對「變化」反應）。
    private func requestCreate(_ target: Mode) {
        showAddSheet = false
        if mode == target {
            createToken += 1
        } else {
            mode = target
            DispatchQueue.main.async { createToken += 1 }
        }
    }

    @ViewBuilder
    private var subtab: some View {
        switch mode {
        case .exercises:
            ExerciseListView(viewModel: exerciseViewModel, createToken: createToken)
        case .templates:
            TemplateListView(viewModel: templateViewModel, createToken: createToken)
        case .rotation:
            RotationListView(viewModel: rotationListViewModel, makeDetail: makeRotationDetail, createToken: createToken)
        case .program:
            ProgramListView(viewModel: programListViewModel, makeDetail: makeProgramDetail, createToken: createToken)
        }
    }
}
