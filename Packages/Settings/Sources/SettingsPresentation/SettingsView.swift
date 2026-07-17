import SwiftUI

public struct SettingsView: View {
    @Bindable private var viewModel: SettingsViewModel
    /// 目前建置環境（"dev" / "prod"）；nil＝不顯示。
    private let environmentBadge: String?

    public init(viewModel: SettingsViewModel, environmentBadge: String? = nil) {
        self.viewModel = viewModel
        self.environmentBadge = environmentBadge
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("外觀") {
                    Picker("主題", selection: $viewModel.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.navigationLink)
                    #endif
                }

                Section("App 圖示") {
                    Picker("App 圖示", selection: $viewModel.icon) {
                        ForEach(AppIcon.allCases) { icon in
                            Label {
                                Text(icon.displayName)
                            } icon: {
                                Image(icon.previewImageName)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .tag(icon)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.navigationLink)
                    #endif
                }

                Section {
                    Toggle("彈窗", isOn: $viewModel.restReminder.popup)
                    Toggle("聲音", isOn: $viewModel.restReminder.sound)
                    Toggle("震動", isOn: $viewModel.restReminder.haptic)
                } header: {
                    Text("休息結束提醒（App 開著時）")
                }

                Section {
                    Toggle("背景通知", isOn: $viewModel.restReminder.backgroundNotification)
                } header: {
                    Text("休息結束提醒（背景／鎖屏）")
                } footer: {
                    Text("App 不在前景時以系統通知提醒；是否有聲音跟隨上方「聲音」開關，是否震動由系統設定決定。關閉後背景將完全不提醒。")
                }

                if let environmentBadge {
                    Section("環境") {
                        HStack {
                            Text("建置環境")
                            Spacer()
                            Text(environmentBadge)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("environmentBadge")
                        }
                    }
                }
            }
            .navigationTitle("設定")
        }
    }
}
