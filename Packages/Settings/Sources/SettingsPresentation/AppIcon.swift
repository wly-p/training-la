import SwiftUI

/// App icon 選項。`assetName == nil` 代表預設 icon（asset catalog 裡的主要 `AppIcon`）。
public enum AppIcon: String, CaseIterable, Identifiable, Sendable {
    case sandArrow
    case stepWave
    case progressCurve
    case rhythmBars
    case barbellPlate
    case checkmark
    case pulseLine
    case concentricCircles

    /// 預設 icon（對應 `UIApplication.setAlternateIconName(nil)`）。
    public static let `default`: AppIcon = .sandArrow

    public var id: String { rawValue }

    /// 對應 Info.plist `CFBundleAlternateIcons` 裡的名稱；nil＝預設 app icon。
    public var assetName: String? {
        switch self {
        case .sandArrow: nil
        case .stepWave: "AppIcon-StepWave"
        case .progressCurve: "AppIcon-ProgressCurve"
        case .rhythmBars: "AppIcon-RhythmBars"
        case .barbellPlate: "AppIcon-BarbellPlate"
        case .checkmark: "AppIcon-Checkmark"
        case .pulseLine: "AppIcon-PulseLine"
        case .concentricCircles: "AppIcon-ConcentricCircles"
        }
    }

    /// String Catalog 的 key（繁中值見 `Localizable.xcstrings`）；View 用 `localText(_:)` 套 `bundle: .module`。
    public var displayName: LocalizedStringKey {
        switch self {
        case .sandArrow: "settings.appIcon.sandArrow"
        case .stepWave: "settings.appIcon.stepWave"
        case .progressCurve: "settings.appIcon.progressCurve"
        case .rhythmBars: "settings.appIcon.rhythmBars"
        case .barbellPlate: "settings.appIcon.barbellPlate"
        case .checkmark: "settings.appIcon.checkmark"
        case .pulseLine: "settings.appIcon.pulseLine"
        case .concentricCircles: "settings.appIcon.concentricCircles"
        }
    }

    /// UI 預覽縮圖的 asset 名稱：另外放一份一般 image set（跟 App Icon 類型的 asset 分開），
    /// 因為 App Icon asset 不保證能被 SwiftUI `Image(_:)` 直接讀到。
    public var previewImageName: String {
        "IconPreview-\(rawValue)"
    }

    /// 從 `IconSwitching.currentIconName`（`UIApplication.alternateIconName`）反解回這個 enum。
    public init(assetName: String?) {
        self = AppIcon.allCases.first { $0.assetName == assetName } ?? .default
    }
}
