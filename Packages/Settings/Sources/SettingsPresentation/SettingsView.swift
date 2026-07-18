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
                } header: {
                    Text("休息結束提醒（App 開著時）")
                } footer: {
                    Text("有聲音時系統會伴隨震動，無法分開設定。")
                }

                Section {
                    Toggle("背景通知", isOn: $viewModel.restReminder.backgroundNotification)
                } header: {
                    Text("休息結束提醒（背景／鎖屏）")
                } footer: {
                    Text("App 不在前景時以系統通知提醒；是否有聲音跟隨上方「聲音」開關。關閉後背景將完全不提醒。")
                }

                Section {
                    Button(role: .destructive) {
                        showEraseConfirm = true
                    } label: {
                        HStack {
                            Text("刪除所有資料")
                            if viewModel.isErasing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isErasing)
                    .accessibilityIdentifier("deleteAllDataButton")
                } header: {
                    Text("資料")
                } footer: {
                    Text("清除所有動作、課表與訓練紀錄，App 回到初始狀態。外觀設定（主題、App 圖示）會保留。此動作無法復原。")
                }

                if let appVersion {
                    Section("關於") {
                        HStack {
                            Text("版本")
                            Spacer()
                            Text(appVersion)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .accessibilityIdentifier("appVersion")
                        }
                    }
                }
            }
            .navigationTitle("設定")
            // 用 alert 不用 confirmationDialog：iOS 26 的 confirmationDialog 會以帶箭頭的 popover
            // 呈現且錨點不在觸發按鈕上；alert 固定置中、無箭頭。
            .alert(
                "確定刪除所有資料？",
                isPresented: $showEraseConfirm
            ) {
                Button("刪除所有資料", role: .destructive) {
                    Task { await viewModel.eraseAllData() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("所有動作、課表與訓練紀錄將被永久刪除，且無法復原。")
            }
            .alert("刪除失敗", isPresented: $viewModel.eraseFailed) {
                Button("好", role: .cancel) {}
            } message: {
                Text("刪除資料時發生錯誤，請再試一次。")
            }
        }
    }
}
