import SwiftUI

public struct SettingsView: View {
    @Bindable private var viewModel: SettingsViewModel
    /// 目前連的環境（"dev · training-la-api-dev.wly.lol"）；nil＝不顯示。
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

                if let environmentBadge {
                    Section("環境") {
                        HStack {
                            Text("目前連線")
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
