import Foundation
import TrainingDomain

/// 14c 重量來源標示的純格式化邏輯：算式文字／強度膠囊/待填原因。跟 View 分開方便單獨測。
enum WeightSourceFormatting {
    /// 算式文字（`accent-700`，列在動作名下方）。回 nil＝這列不值得多解釋
    /// （沒設表達式、或單純絕對值又沒套強度倍率——右側數字本身已經說明一切）。
    static func algebraText(_ source: TargetWeightSource?) -> String? {
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
            return "\(percentString(percent / 100))\(factorSuffix) · 最大重量 \(ability.displayString)"
        case .relativeToLast:
            guard let last = source.lastWeight, let delta = source.delta else { return nil }
            let sign = delta.value >= 0 ? "+" : ""
            return "上次 \(last.displayString) \(sign)\(delta.displayString)\(factorSuffix)"
        }
    }

    /// 算不出來的原因（待填膠囊的副標）；resolvable 時回 nil。
    static func unresolvedReason(_ source: TargetWeightSource?) -> String? {
        guard let source, source.isUnresolved else { return nil }
        switch source.kind {
        case .none: return String(localized: "training.weightSource.reason.none", bundle: .module)
        case .relativeToLast: return String(localized: "training.weightSource.reason.noLast", bundle: .module)
        case .percentOfMax: return String(localized: "training.weightSource.reason.noAbility", bundle: .module)
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
