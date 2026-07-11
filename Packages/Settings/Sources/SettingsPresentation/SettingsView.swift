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
