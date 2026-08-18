import DesignSystem
import SharedKernel
import SwiftUI

public struct SettingsView: View {
    /// 目前語言：`localString` 要靠它才能查到 app 設定的語言（而非手機語系）。
    @Environment(\.locale) private var locale
    @Bindable private var viewModel: SettingsViewModel
    /// App 版號顯示字串（例："1.0.0 (1)"）；nil＝不顯示。
    private let appVersion: String?
    /// 隱私政策頁網址（不含語言 fragment，由 App 層從 Info.plist 讀進來）；
    /// nil＝不顯示那一列，寧可沒有入口也不要給一個點了沒反應的列。
    private let privacyPolicyBaseURL: URL?

    @State private var showEraseConfirm = false
    @State private var showPrivacyPolicy = false
    @State private var route: SettingsRoute?
    /// 「我的能力值」畫面住在 Ability package（Presentation-to-Presentation 不互相 import，
    /// 靠 App 層組裝時注入這個 view builder，型別抹成 AnyView）。nil＝不顯示這一列
    /// （例如 SwiftUI 預覽或還沒接 Ability 的情境）。
    private let abilityDestination: (() -> AnyView)?

    private enum SettingsRoute: Hashable { case theme, language, icon, ability, weightStep, restStep }

    public init(
        viewModel: SettingsViewModel,
        appVersion: String? = nil,
        privacyPolicyBaseURL: URL? = nil,
        abilityDestination: (() -> AnyView)? = nil
    ) {
        self.viewModel = viewModel
        self.appVersion = appVersion
        self.privacyPolicyBaseURL = privacyPolicyBaseURL
        self.abilityDestination = abilityDestination
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PageHeader(localText("settings.title"))
                        .accessibilityIdentifier("settings.title")

                    // 群組間距 22（handoff-20 A 節）：比全域的 TLSpace.section(26) 緊一點，
                    // 這一頁的群組多，26 會把「資料」那兩張卡推到看不見的地方。
                    VStack(alignment: .leading, spacing: 22) {
                        appearanceSection
                        trainingPreferenceSection
                        restReminderSection
                        dataSection
                        versionFooter
                    }
                    .padding(.horizontal, TLSpace.page)
                    .padding(.top, TLSpace.section)
                }
                .padding(.bottom, 40)
            }
            .background(TLColor.bg.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .navigationDestination(item: $route) { destination($0) }
            .tlConfirmationDialog(
                isPresented: $showEraseConfirm,
                title: localText("settings.eraseAll.confirm.title"),
                message: localText("settings.eraseAll.confirm.message"),
                confirmLabel: localText("settings.eraseAll.button"),
                cancelLabel: localText("settings.common.cancel"),
                role: .destructive,
                confirmIdentifier: "settings.eraseAll.confirm",
                onConfirm: { Task { await viewModel.eraseAllData() } }
            )
            .alert(
                localText("settings.eraseFailed.title"),
                isPresented: $viewModel.eraseFailed
            ) {
                Button(role: .cancel) {} label: { localText("settings.common.ok") }
            } message: {
                localText("settings.eraseFailed.message")
            }
            #if os(iOS)
            .sheet(isPresented: $showPrivacyPolicy) {
                if let privacyPolicyURL {
                    SafariView(url: privacyPolicyURL)
                        .ignoresSafeArea()
                }
            }
            #endif
        }
    }

    // MARK: - 外觀

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(localText("settings.appearance.section"))
            TLGroup {
                SettingsRow(
                    localText("settings.theme.title"),
                    showChevron: true,
                    accessibilityValue: localText(viewModel.theme.displayName),
                    onTap: { route = .theme }
                ) {
                    SettingsValue(localText(viewModel.theme.displayName))
                }
                .accessibilityIdentifier("settings.row.theme")
                SettingsRow(
                    localText("settings.language.title"),
                    showChevron: true,
                    accessibilityValue: Text(verbatim: viewModel.language.nativeName),
                    onTap: { route = .language }
                ) {
                    SettingsValue(Text(verbatim: viewModel.language.nativeName))
                }
                .accessibilityIdentifier("settings.row.language")
                SettingsRow(
                    localText("settings.appIcon.title"),
                    showChevron: true,
                    accessibilityValue: localText(viewModel.icon.displayName),
                    trailingGap: 10,   // 預覽方塊比一行值文字重，離 chevron 遠一點
                    onTap: { route = .icon }
                ) {
                    Image(viewModel.icon.previewImageName)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .accessibilityIdentifier("settings.row.appIcon")
            }
        }
    }

    // MARK: - 訓練偏好
    //
    // 重量單位、兩個級距、能力值都是「算重量／算休息」用的參數，屬於同一組；
    // 外觀只留「看起來怎樣」。能力值是這組唯一會導向下一頁的列，所以排在最後。

    private var trainingPreferenceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(localText("settings.trainingPreference.section"))
            TLGroup {
                SettingsRow(localText("settings.weightUnit.title")) {
                    // compact：整顆 26pt，不撐高 56pt 的列，也不再是全頁最亮的元素。
                    TLSegmentedControl(
                        selection: Binding(
                            get: { viewModel.weightUnit.rawValue },
                            set: { viewModel.weightUnit = WeightUnit(rawValue: $0) ?? .kg }
                        ),
                        options: WeightUnit.allCases.map { .init($0.rawValue, $0.rawValue) },
                        size: .compact
                    )
                }
                .accessibilityIdentifier("settings.row.weightUnit")
                SettingsRow(
                    localText("settings.weightStep.title"),
                    showChevron: true,
                    accessibilityValue: Text(verbatim: Weight.formatted(viewModel.weightStep)),
                    onTap: { route = .weightStep }
                ) {
                    SettingsValue(
                        Text(verbatim: "\(Weight.formatted(viewModel.weightStep)) \(viewModel.weightUnit.rawValue)")
                    )
                }
                .accessibilityIdentifier("settings.row.weightStep")
                SettingsRow(
                    localText("settings.restStep.title"),
                    showChevron: true,
                    accessibilityValue: Text(verbatim: "\(viewModel.restStep)"),
                    onTap: { route = .restStep }
                ) {
                    SettingsValue(localText("settings.restStep.value \(viewModel.restStep)"))
                }
                .accessibilityIdentifier("settings.row.restStep")
                if abilityDestination != nil {
                    SettingsRow(
                        localText("settings.ability.title"),
                        showChevron: true,
                        onTap: { route = .ability }
                    )
                    .accessibilityIdentifier("settings.row.ability")
                }
            }
        }
    }

    // MARK: - 休息結束提醒

    private var restReminderSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(localText("settings.restReminder.section"))
                .accessibilityIdentifier("settings.restReminder.header")
            TLGroup {
                SettingsToggleRow(
                    localText("settings.restReminder.popup"),
                    isOn: $viewModel.restReminder.popup
                )
                .accessibilityIdentifier("settings.toggle.popup")
                SettingsToggleRow(
                    localText("settings.restReminder.sound"),
                    hint: localText("settings.restReminder.sound.hint"),
                    isOn: $viewModel.restReminder.sound
                )
                .accessibilityIdentifier("settings.toggle.sound")
                // 說明原本是整組下方的獨立段落，會讓人分不清它在解釋整組還是最後一列；
                // 改成這一列自己的副標（同「聲音／含震動」的歸屬，只是句子長、排第二行）。
                SettingsToggleRow(
                    localText("settings.restReminder.background.toggle"),
                    subtitle: localText("settings.restReminder.background.hint"),
                    isOn: $viewModel.restReminder.backgroundNotification
                )
                .accessibilityIdentifier("settings.toggle.background")
            }
        }
    }

    // MARK: - 資料 ＋ 刪除

    /// 刪除獨立成第二張卡：同卡內的分隔線代表「同一類」，
    /// 破壞性操作不屬於「匯出／隱私」那一類。兩張卡共用「資料」這個群組標題。
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(localText("settings.data.header"))
                TLGroup {
                    exportRow
                    // 隱私政策沒有自己的設計稿；併進「資料」區而不是另開一個只有一列的「關於」群組。
                    if privacyPolicyBaseURL != nil {
                        SettingsRow(
                            localText("settings.privacy.title"),
                            showChevron: true,
                            onTap: { showPrivacyPolicy = true }
                        )
                        .accessibilityIdentifier("settings.row.privacy")
                    }
                }
            }
            TLGroup {
                SettingsRow(
                    localText("settings.eraseAll.button"),
                    role: .destructive,
                    onTap: { if !viewModel.isErasing { showEraseConfirm = true } }
                ) {
                    if viewModel.isErasing { ProgressView() }
                }
                .accessibilityIdentifier("settings.row.eraseAll")
            }
        }
    }

    /// 匯出資料＝佔位、停用（Domain/Data 尚未實作）。
    /// 不能只用灰字表示——純灰字會被讀成壞掉；整列降透明度（設計系統的 disabled 規則）、
    /// 拿掉 chevron（沒有下一頁）、右側明說「尚未開放」。
    private var exportRow: some View {
        SettingsRow(localText("settings.export.title")) {
            localText("settings.export.unavailable")
                .font(TLFont.zh(13))
                .foregroundStyle(TLColor.neutral600)
        }
        .accessibilityIdentifier("settings.row.export")
        .opacity(0.45)
        .allowsHitTesting(false)
    }

    /// 政策頁是線上的單一來源，App 不打包副本——所以開的是網址，離線就是 Safari 的錯誤頁。
    /// 語言 fragment **在開啟當下才算**：使用者可能上一秒才在這一頁把語言改掉。
    private var privacyPolicyURL: URL? {
        privacyPolicyBaseURL.map { PrivacyPolicy.localizedURL(base: $0, language: viewModel.language) }
    }

    // MARK: - 版號

    /// 不用 Caprasimo：那支字體的角色是「數據要有個性」（訓練頁大數字、統計），
    /// 版本號是元資料不是數據，用一般 sans 12pt regular，安靜地待在最下面就好。
    @ViewBuilder
    private var versionFooter: some View {
        if let appVersion {
            Text(appVersion)
                .font(TLFont.en(12, .regular))
                .foregroundStyle(TLColor.neutral500)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("settings.version")
        }
    }

    // MARK: - drill-in 目的地

    /// 休息級距的合法範圍換成 Double（`StepPreferenceView` 重量／秒數共用同一個型別）。
    private var restStepRangeAsDouble: ClosedRange<Double> {
        let range = InMemoryTrainingPreferenceStore.restStepRange
        return Double(range.lowerBound)...Double(range.upperBound)
    }

    @ViewBuilder
    private func destination(_ destinationRoute: SettingsRoute) -> some View {
        switch destinationRoute {
        case .theme:
            SettingsSelectionView(
                title: localText("settings.theme.title"),
                options: AppTheme.allCases,
                current: viewModel.theme,
                label: { localText($0.displayName) },
                leadingImageName: nil,
                onSelect: { viewModel.theme = $0; route = nil },
                onBack: { route = nil }
            )
        case .language:
            SettingsSelectionView(
                title: localText("settings.language.title"),
                options: AppLanguage.allCases,
                current: viewModel.language,
                label: { Text(verbatim: $0.nativeName) },
                leadingImageName: nil,
                onSelect: { viewModel.language = $0; route = nil },
                onBack: { route = nil }
            )
        case .icon:
            SettingsSelectionView(
                title: localText("settings.appIcon.title"),
                options: AppIcon.allCases,
                current: viewModel.icon,
                label: { localText($0.displayName) },
                leadingImageName: { $0.previewImageName },
                onSelect: { viewModel.icon = $0; route = nil },
                onBack: { route = nil }
            )
        case .weightStep:
            StepPreferenceView(
                title: localText("settings.weightStep.title"),
                options: [0.5, 1, 1.25, 2, 2.5, 5],
                range: InMemoryTrainingPreferenceStore.weightStepRange,
                unitLabel: viewModel.weightUnit.rawValue,
                allowsDecimal: true,
                current: viewModel.weightStep,
                onSelect: { viewModel.weightStep = $0 },
                onBack: { route = nil }
            )
        case .restStep:
            StepPreferenceView(
                title: localText("settings.restStep.title"),
                options: [10, 15, 30, 60],
                range: restStepRangeAsDouble,
                unitLabel: localString("settings.restStep.unit", locale),
                allowsDecimal: false,
                current: Double(viewModel.restStep),
                onSelect: { viewModel.restStep = Int($0) },
                onBack: { route = nil }
            )
        case .ability:
            if let abilityDestination {
                abilityDestination()
            }
        }
    }
}
