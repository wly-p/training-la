import SwiftUI

public struct SettingsView: View {
    @Bindable private var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
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
            }
            .navigationTitle("設定")
        }
    }
}
