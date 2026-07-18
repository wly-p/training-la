import Foundation
import Observation
import RemindersDomain
import SharedKernel

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

    /// 休息結束提醒偏好；改動即持久化。
    public var restReminder: RestReminderPreference {
        didSet { restReminderStore.save(restReminder) }
    }

    /// 目前語言；改動即持久化。RootView 讀它套 `.environment(\.locale, …)`，切換即時重繪全 App。
    public var language: AppLanguage {
        didSet { languageStore.save(language) }
    }

    /// 「刪除所有資料」進行中；UI 用來顯示進度並鎖住按鈕、防重複觸發。
    public private(set) var isErasing = false
    /// 刪除失敗；綁 UI 的錯誤 alert。
    public var eraseFailed = false

    private let store: any ThemeStoring
    private let iconSwitcher: any IconSwitching
    private let restReminderStore: any RestReminderPreferenceStoring
    private let languageStore: any LanguagePreferenceStoring
    private let dataEraser: any DataErasing
    /// 清除成功後由 App 層觸發整個畫面重建（回到全新初始狀態）。
    private let onErased: @MainActor () -> Void

    public init(
        store: any ThemeStoring,
        iconSwitcher: any IconSwitching,
        restReminderStore: any RestReminderPreferenceStoring = InMemoryRestReminderPreferenceStore(),
        languageStore: any LanguagePreferenceStoring = InMemoryLanguageStore(),
        systemPreferredLanguages: [String] = Locale.preferredLanguages,
        dataEraser: any DataErasing = NoopDataEraser(),
        onErased: @escaping @MainActor () -> Void = {}
    ) {
        self.store = store
        self.iconSwitcher = iconSwitcher
        self.restReminderStore = restReminderStore
        self.languageStore = languageStore
        self.dataEraser = dataEraser
        self.onErased = onErased
        self.theme = store.load() // init 期間 didSet 不觸發，不會多存一次
        self.icon = AppIcon(assetName: iconSwitcher.currentIconName)
        self.restReminder = restReminderStore.load()
        // 第一次啟動（store 為空）：由系統偏好語言決定、命中支援清單就用、否則 fallback，
        // 並 seed 回 store → 之後一律以設定為主，不再看系統。
        let storedLanguage = languageStore.load()
        self.language = LanguageResolver.resolve(stored: storedLanguage, systemPreferred: systemPreferredLanguages)
        if storedLanguage == nil { languageStore.save(language) }
    }

    /// 清空所有本機資料（動作庫、課表、訓練紀錄）；顯示偏好（主題、圖示）保留。
    /// 成功後呼叫 `onErased` 讓 App 重建畫面。應在使用者二次確認後才呼叫。
    public func eraseAllData() async {
        guard !isErasing else { return }
        isErasing = true
        do {
            try await dataEraser.eraseAllData()
            isErasing = false
            onErased()
        } catch {
            isErasing = false
            eraseFailed = true
        }
    }
}
