import Foundation
import Observation

@MainActor
@Observable
public final class SettingsViewModel {
    /// 目前主題。改動即持久化；RootView 讀它套 `.preferredColorScheme`。
    public var theme: AppTheme {
        didSet { store.save(theme) }
    }

    private let store: any ThemeStoring

    public init(store: any ThemeStoring) {
        self.store = store
        self.theme = store.load() // init 期間 didSet 不觸發，不會多存一次
    }
}
