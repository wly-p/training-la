import Foundation
import Observation
import RemindersDomain
import SharedKernel

/// 匯出成功產生的檔案；`Identifiable` 讓 `.sheet(item:)` 可以直接綁它。
public struct ExportedFile: Identifiable, Equatable {
    public let url: URL
    public var id: URL { url }
    public init(url: URL) { self.url = url }
}

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

    /// 系統實際拒絕了通知授權——偏好可能仍顯示「背景通知」開著，但已經完全失效。
    /// 由 `refreshNotificationAuthorization()` 更新（View 用 `.task`／回到前景時呼叫，
    /// 因為使用者可能離開去系統設定改了才回來）。
    public private(set) var notificationAuthorizationDenied = false

    /// 目前語言；改動即持久化。RootView 讀它套 `.environment(\.locale, …)`，切換即時重繪全 App。
    public var language: AppLanguage {
        didSet { languageStore.save(language) }
    }

    /// 預設重量單位；改動即持久化。只影響**之後**輸入的預設單位與顯示，
    /// 既有紀錄各自留著當初輸入的單位（換算在比較與顯示時發生，見 `Weight`）。
    public var weightUnit: WeightUnit {
        didSet { weightUnitStore.save(weightUnit) }
    }

    /// 調整重量的級距；改動即持久化。訓練頁 ± 快捷、選擇器滾輪、投影收斂取整都吃這個值。
    public var weightStep: Double {
        didSet { preferences.saveWeightStep(weightStep) }
    }

    /// 調整休息時間的級距（秒）；改動即持久化。
    public var restStep: Int {
        didSet { preferences.saveRestStep(restStep) }
    }

    /// 「刪除所有資料」進行中；UI 用來顯示進度並鎖住按鈕、防重複觸發。
    public private(set) var isErasing = false
    /// 刪除失敗；綁 UI 的錯誤 alert。
    public var eraseFailed = false

    /// 匯出進行中；UI 用來顯示進度並鎖住按鈕、防重複觸發。
    public private(set) var isExporting = false
    /// 匯出失敗；綁 UI 的錯誤 alert。
    public var exportFailed = false
    /// 匯出成功產生的檔案；UI 用 `.sheet(item:)` 呼出分享面板。
    public var exportedFile: ExportedFile?

    private let store: any ThemeStoring
    private let iconSwitcher: any IconSwitching
    private let restReminderStore: any RestReminderPreferenceStoring
    private let notificationAuthorization: any NotificationAuthorizationChecking
    private let languageStore: any LanguagePreferenceStoring
    private let weightUnitStore: any WeightUnitPreferenceStoring
    private let preferences: any TrainingPreferenceStoring
    private let dataEraser: any DataErasing
    private let historyExporter: any WorkoutHistoryExporting
    /// 清除成功後由 App 層觸發整個畫面重建（回到全新初始狀態）。
    private let onErased: @MainActor () -> Void

    public init(
        store: any ThemeStoring,
        iconSwitcher: any IconSwitching,
        restReminderStore: any RestReminderPreferenceStoring = InMemoryRestReminderPreferenceStore(),
        notificationAuthorization: any NotificationAuthorizationChecking = NoopNotificationAuthorizationChecking(),
        languageStore: any LanguagePreferenceStoring = InMemoryLanguageStore(),
        weightUnitStore: any WeightUnitPreferenceStoring = InMemoryWeightUnitStore(),
        preferences: any TrainingPreferenceStoring = InMemoryTrainingPreferenceStore(),
        systemPreferredLanguages: [String] = Locale.preferredLanguages,
        dataEraser: any DataErasing = NoopDataEraser(),
        historyExporter: any WorkoutHistoryExporting = NoopWorkoutHistoryExporting(),
        onErased: @escaping @MainActor () -> Void = {}
    ) {
        self.store = store
        self.iconSwitcher = iconSwitcher
        self.restReminderStore = restReminderStore
        self.notificationAuthorization = notificationAuthorization
        self.languageStore = languageStore
        self.weightUnitStore = weightUnitStore
        self.preferences = preferences
        self.historyExporter = historyExporter
        self.dataEraser = dataEraser
        self.onErased = onErased
        self.theme = store.load() // init 期間 didSet 不觸發，不會多存一次
        self.icon = AppIcon(assetName: iconSwitcher.currentIconName)
        self.restReminder = restReminderStore.load()
        self.weightUnit = weightUnitStore.load()
        self.weightStep = preferences.loadWeightStep()
        self.restStep = preferences.loadRestStep()
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

    /// 重查系統通知授權狀態。View 用 `.task`／回到前景時呼叫——
    /// 使用者可能離開這頁去系統設定改了授權，回來要反映最新狀態，不能只在 init 查一次。
    public func refreshNotificationAuthorization() async {
        notificationAuthorizationDenied = await notificationAuthorization.currentStatus() == .denied
    }

    public func exportJSON() async {
        await runExport { try await historyExporter.exportJSON() }
    }

    public func exportCSV() async {
        await runExport { try await historyExporter.exportCSV() }
    }

    private func runExport(_ export: () async throws -> URL) async {
        guard !isExporting else { return }
        isExporting = true
        do {
            let url = try await export()
            isExporting = false
            exportedFile = ExportedFile(url: url)
        } catch {
            isExporting = false
            exportFailed = true
        }
    }
}
