import SwiftUI

public struct SettingsView: View {
    @Bindable private var viewModel: SettingsViewModel
    /// 目前建置環境（"dev" / "prod"）；nil＝不顯示。
    private let environmentBadge: String?
    @State private var showEraseConfirm = false

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
            }
            .navigationTitle("設定")
            .confirmationDialog(
                "確定刪除所有資料？",
                isPresented: $showEraseConfirm,
                titleVisibility: .visible
            ) {
                Button("刪除所有資料", role: .destructive) {
                    Task { await viewModel.eraseAllData() }
                }
                .accessibilityIdentifier("confirmDeleteAllDataButton")
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
