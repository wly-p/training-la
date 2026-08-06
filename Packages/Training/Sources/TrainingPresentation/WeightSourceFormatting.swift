import Foundation
import TrainingDomain

/// 14c 重量來源標示的純格式化邏輯：算式文字／強度膠囊/待填原因。跟 View 分開方便單獨測。
///
/// 會產文字的兩個函式都收 `locale`：它們拿不到 SwiftUI Environment，而語言必須跟著 app 設定走，
/// 不能吃 process locale。呼叫端都是 View，`@Environment(\.locale)` 直接傳進來即可
/// （formatter 收 `Locale` 也是 Foundation 一貫的形狀，順便讓測試能指定語言）。
enum WeightSourceFormatting {
    /// 算式文字（`accent-700`，列在動作名下方）。回 nil＝這列不值得多解釋
    /// （沒設表達式、或單純絕對值又沒套強度倍率——右側數字本身已經說明一切）。
    static func algebraText(_ source: TargetWeightSource?, locale: Locale) -> String? {
        guard let source else { return nil }
        let factorSuffix = source.intensityFactor == 1.0 ? "" : " · × \(percentString(source.intensityFactor))"
        switch source.kind {
        case .none:
            return nil
        case .absolute:
            guard source.intensityFactor != 1.0, let base = source.base else { return nil }
            return "\(base.displayString) × \(percentString(source.intensityFactor))"
        case .percentOfMax:
            guard let percent = source.percent, let ability = source.abilityValue else { return nil }
            let label = localString("training.weightSource.maxWeightLabel", locale)
            return "\(percentString(percent / 100))\(factorSuffix) · \(label) \(ability.displayString)"
        case .relativeToLast:
            guard let last = source.lastWeight, let delta = source.delta else { return nil }
            let sign = delta.value >= 0 ? "+" : ""
            let label = localString("training.weightSource.lastLabel", locale)
            return "\(label) \(last.displayString) \(sign)\(delta.displayString)\(factorSuffix)"
        }
    }

    /// 算不出來的原因（待填膠囊的副標）；resolvable 時回 nil。
    static func unresolvedReason(_ source: TargetWeightSource?, locale: Locale) -> String? {
        guard let source, source.isUnresolved else { return nil }
        switch source.kind {
        case .none: return localString("training.weightSource.reason.none", locale)
        case .relativeToLast: return localString("training.weightSource.reason.noLast", locale)
        case .percentOfMax: return localString("training.weightSource.reason.noAbility", locale)
        case .absolute: return nil   // .absolute 一定 resolvable，不會走到這
        }
    }

    /// 強度膠囊文字：`×75%`。基準（1.0）回 nil，呼叫端不顯示膠囊。
    static func intensityPillText(_ factor: Double) -> String? {
        factor == 1.0 ? nil : "×\(percentString(factor))"
    }

    private static func percentString(_ factor: Double) -> String {
        String(format: "%.0f%%", factor * 100)
    }
}
