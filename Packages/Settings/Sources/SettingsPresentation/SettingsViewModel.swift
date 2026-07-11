import Foundation
import Observation

@MainActor
@Observable
public final class SettingsViewModel {
    /// 目前主題。改動即持久化；RootView 讀它套 `.preferredColorScheme`。
    public var theme: AppTheme {
        didSet { store.save(theme) }
    }

    /// 目前 app icon。改動即呼叫 `UIApplication.setAlternateIconName`。
    public var icon: AppIcon {
        didSet {
            guard icon != oldValue else { return }
            let target = icon
            Task { [iconSwitcher] in
                do {
                    try await iconSwitcher.setIcon(target.assetName)
                } catch {
                    // 系統若拒絕切換（例如使用者取消系統彈窗），維持顯示原本選取值即可，不擋 App 其他功能。
                }
            }
        }
    }

    private let store: any ThemeStoring
    private let iconSwitcher: any IconSwitching

    public init(store: any ThemeStoring, iconSwitcher: any IconSwitching) {
        self.store = store
        self.iconSwitcher = iconSwitcher
        self.theme = store.load() // init 期間 didSet 不觸發，不會多存一次
        self.icon = AppIcon(assetName: iconSwitcher.currentIconName)
    }
}
