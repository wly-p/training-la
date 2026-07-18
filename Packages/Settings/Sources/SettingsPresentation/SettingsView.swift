import SwiftUI

public struct SettingsView: View {
    @Bindable private var viewModel: SettingsViewModel
    /// App 版號顯示字串（例："1.0.0 (1)"）；nil＝不顯示。
    private let appVersion: String?
    @State private var showEraseConfirm = false

    public init(viewModel: SettingsViewModel, appVersion: String? = nil) {
        self.viewModel = viewModel
        self.appVersion = appVersion
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(selection: $viewModel.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            localText(theme.displayName).tag(theme)
                        }
                    } label: {
                        localText("settings.theme.title")
                    }
                    #if os(iOS)
                    .pickerStyle(.navigationLink)
                    #endif
                } header: {
                    localText("settings.appearance.section")
                }

                Section {
                    Picker(selection: $viewModel.icon) {
                        ForEach(AppIcon.allCases) { icon in
                            Label {
                                localText(icon.displayName)
                            } icon: {
                                Image(icon.previewImageName)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .tag(icon)
                        }
                    } label: {
                        localText("settings.appIcon.title")
                    }
                    #if os(iOS)
                    .pickerStyle(.navigationLink)
                    #endif
                } header: {
                    localText("settings.appIcon.title")
                }

                Section {
                    Toggle(isOn: $viewModel.restReminder.popup) {
                        localText("settings.restReminder.popup")
                    }
                    Toggle(isOn: $viewModel.restReminder.sound) {
                        localText("settings.restReminder.sound")
                    }
                } header: {
                    localText("settings.restReminder.foreground.header")
                } footer: {
                    localText("settings.restReminder.foreground.footer")
                }

                Section {
                    Toggle(isOn: $viewModel.restReminder.backgroundNotification) {
                        localText("settings.restReminder.background.toggle")
                    }
                } header: {
                    localText("settings.restReminder.background.header")
                } footer: {
                    localText("settings.restReminder.background.footer")
                }

                Section {
                    Button(role: .destructive) {
                        showEraseConfirm = true
                    } label: {
                        HStack {
                            localText("settings.eraseAll.button")
                            if viewModel.isErasing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isErasing)
                    .accessibilityIdentifier("deleteAllDataButton")
                } header: {
                    localText("settings.data.header")
                } footer: {
                    localText("settings.data.footer")
                }

                if let appVersion {
                    Section {
                        HStack {
                            localText("settings.version.title")
                            Spacer()
                            Text(appVersion)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .accessibilityIdentifier("appVersion")
                        }
                    } header: {
                        localText("settings.about.section")
                    }
                }
            }
            .navigationTitle(localText("settings.title"))
            // 用 alert 不用 confirmationDialog：iOS 26 的 confirmationDialog 會以帶箭頭的 popover
            // 呈現且錨點不在觸發按鈕上；alert 固定置中、無箭頭。
            .alert(
                localText("settings.eraseAll.confirm.title"),
                isPresented: $showEraseConfirm
            ) {
                Button(role: .destructive) {
                    Task { await viewModel.eraseAllData() }
                } label: {
                    localText("settings.eraseAll.button")
                }
                Button(role: .cancel) {} label: {
                    localText("settings.common.cancel")
                }
            } message: {
                localText("settings.eraseAll.confirm.message")
            }
            .alert(
                localText("settings.eraseFailed.title"),
                isPresented: $viewModel.eraseFailed
            ) {
                Button(role: .cancel) {} label: {
                    localText("settings.common.ok")
                }
            } message: {
                localText("settings.eraseFailed.message")
            }
        }
    }
}
