import DesignSystem
import SharedKernel
import SwiftUI

public struct SettingsView: View {
    @Bindable private var viewModel: SettingsViewModel
    /// App 版號顯示字串（例："1.0.0 (1)"）；nil＝不顯示。
    private let appVersion: String?

    @State private var showEraseConfirm = false
    @State private var route: SettingsRoute?
    /// 「我的能力值」畫面住在 Ability package（Presentation-to-Presentation 不互相 import，
    /// 靠 App 層組裝時注入這個 view builder，型別抹成 AnyView）。nil＝不顯示這一列
    /// （例如 SwiftUI 預覽或還沒接 Ability 的情境）。
    private let abilityDestination: (() -> AnyView)?

    private enum SettingsRoute: Hashable { case theme, language, icon, ability }

    public init(
        viewModel: SettingsViewModel,
        appVersion: String? = nil,
        abilityDestination: (() -> AnyView)? = nil
    ) {
        self.viewModel = viewModel
        self.appVersion = appVersion
        self.abilityDestination = abilityDestination
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PageHeader(localText("settings.title"))

                    VStack(alignment: .leading, spacing: TLSpace.section) {
                        appearanceSection
                        if abilityDestination != nil {
                            abilitySection
                        }
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
                confirmIdentifier: "eraseConfirmButton",
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
                SettingsRow(
                    localText("settings.language.title"),
                    showChevron: true,
                    accessibilityValue: Text(verbatim: viewModel.language.nativeName),
                    onTap: { route = .language }
                ) {
                    SettingsValue(Text(verbatim: viewModel.language.nativeName))
                }
                SettingsRow(
                    localText("settings.appIcon.title"),
                    showChevron: true,
                    accessibilityValue: localText(viewModel.icon.displayName),
                    onTap: { route = .icon }
                ) {
                    Image(viewModel.icon.previewImageName)
                        .resizable()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                SettingsRow(localText("settings.weightUnit.title")) {
                    TLSegmentedControl(
                        selection: Binding(
                            get: { viewModel.weightUnit.rawValue },
                            set: { viewModel.weightUnit = WeightUnit(rawValue: $0) ?? .kg }
                        ),
                        options: WeightUnit.allCases.map { .init($0.rawValue, $0.rawValue) }
                    )
                    .frame(width: 128)
                }
            }
        }
    }

    // MARK: - 休息結束提醒

    private var restReminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(localText("settings.restReminder.section"))
                TLGroup {
                    SettingsToggleRow(
                        localText("settings.restReminder.popup"),
                        isOn: $viewModel.restReminder.popup
                    )
                    SettingsToggleRow(
                        localText("settings.restReminder.sound"),
                        hint: localText("settings.restReminder.sound.hint"),
                        isOn: $viewModel.restReminder.sound
                    )
                    SettingsToggleRow(
                        localText("settings.restReminder.background.toggle"),
                        isOn: $viewModel.restReminder.backgroundNotification
                    )
                }
            }
            localText("settings.restReminder.footer")
                .font(TLFont.zh(TLFont.rowSub, .regular))
                .foregroundStyle(TLColor.neutral500)
                .padding(.horizontal, TLSpace.rowInset)
        }
    }

    // MARK: - 能力值

    /// 落點暫定（見 05-settings.md B 節：「它不是設定，這一點待你決定」），先掛在這裡。
    private var abilitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(localText("settings.ability.section"))
            TLGroup {
                SettingsRow(
                    localText("settings.ability.title"),
                    showChevron: true,
                    onTap: { route = .ability }
                )
            }
        }
    }

    // MARK: - 資料

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(localText("settings.data.header"))
            TLGroup {
                // 匯出資料＝佔位、停用（Domain/Data 尚未實作，見設計 handoff 決策）。
                SettingsRow(localText("settings.export.title"), showChevron: true) {
                    EmptyView()
                }
                .opacity(0.4)
                .allowsHitTesting(false)

                SettingsRow(
                    localText("settings.eraseAll.button"),
                    role: .destructive,
                    onTap: { if !viewModel.isErasing { showEraseConfirm = true } }
                ) {
                    if viewModel.isErasing { ProgressView() }
                }
                .accessibilityIdentifier("deleteAllDataButton")
            }
        }
    }

    // MARK: - 版號（設計稿未含；保留以免回退已上線功能與 UITest）

    @ViewBuilder
    private var versionFooter: some View {
        if let appVersion {
            Text(appVersion)
                .font(TLFont.display(13))
                .foregroundStyle(TLColor.neutral500)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("appVersion")
        }
    }

    // MARK: - drill-in 目的地

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
        case .ability:
            if let abilityDestination {
                abilityDestination()
            }
        }
    }
}
