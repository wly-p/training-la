import Foundation
import PlanDomain
import SharedKernel

enum PlanFormatting {
    /// 繁中「臥推 4組 · 肩推 3組」、英文「Bench 4 sets · …」。動作名是 DB 資料；「組/sets」數量單位
    /// 依 `language` 本地化，用 `AppLanguage.localizedString` 明確解析（見該方法註解：
    /// `String(localized:locale:)` 不會依 locale 選語言，這裡不能用）。
    static func summary(_ planWorkout: PlanWorkout, name: (UUID) -> String, language: AppLanguage) -> String {
        summary(blocks: planWorkout.blocks, name: name, language: language)
    }

    static func templateSummary(_ template: WorkoutTemplate, name: (UUID) -> String, language: AppLanguage) -> String {
        summary(blocks: template.blocks, name: name, language: language)
    }

    static func summary(_ spec: WorkoutSpec, name: (UUID) -> String, language: AppLanguage) -> String {
        summary(blocks: spec.blocks, name: name, language: language)
    }

    private static func summary(blocks: [PlanBlock], name: (UUID) -> String, language: AppLanguage) -> String {
        blocks
            .map { block in
                let format = language.localizedString("plan.setCountUnit %lld", bundle: .module)
                let count = String(format: format, block.sets.count)
                return "\(name(block.exerciseId)) \(count)"
            }
            .joined(separator: " · ")
    }

    /// 只列動作名（不帶組數），最多 `maxNames` 個，超出用「+N」——循環/長期匯入範本後的清單副標
    /// 用這個（設計稿 12a：`臥推 · 肩推 · 三頭下壓 +1`），跟範本清單自己的副標（含組數）不同。
    static func exerciseNamesSummary(_ spec: WorkoutSpec, name: (UUID) -> String, maxNames: Int = 3) -> String {
        exerciseNamesSummary(sets: spec.sets, name: name, maxNames: maxNames)
    }

    static func exerciseNamesSummary(sets: [PlanSet], name: (UUID) -> String, maxNames: Int = 3) -> String {
        let blocks = sets.planBlocks
        let shown = blocks.prefix(maxNames).map { name($0.exerciseId) }.joined(separator: " · ")
        let remaining = blocks.count - maxNames
        return remaining > 0 ? "\(shown) +\(remaining)" : shown
    }

    /// 循環課表副標「3 個範本 · 推日 → 拉日」：範本數（本地化單位）＋ workout 名以 → 串接（名稱是使用者資料）。
    /// 過長由列自身 `lineLimit(1)` 截斷。
    static func rotationSummary(_ rotation: Rotation, language: AppLanguage) -> String {
        let countFormat = language.localizedString("rotation.templateCount %lld", bundle: .module)
        let count = String(format: countFormat, rotation.workouts.count)
        guard !rotation.workouts.isEmpty else { return count }
        let names = rotation.workouts.map(\.name).joined(separator: " → ")
        return "\(count) · \(names)"
    }

    /// 長期課表副標「4 個範本 · 7 天週期」：有課天數 ＋ 週期天數（皆本地化）。
    static func programLibrarySummary(_ program: Program, language: AppLanguage) -> String {
        let format = language.localizedString("program.librarySummary %lld %lld", bundle: .module)
        return String(format: format, program.days.count, program.cycleLength)
    }

    // MARK: - 動作列的規格（19a）

    /// 「組數 × 次數」。排課草稿（每組相同）與範本的各組相同分支共用同一個寫法，
    /// 兩個畫面的同一種列不該長得不一樣。
    static func spec(setCount: Int, reps: Int) -> String {
        "\(setCount) × \(reps)"
    }

    // MARK: - 範本摺疊列（19a）

    /// 主行右側的規格。**講的是次數**，不是重量——重量在細節行（見 ``blockWeight(sets:language:)``）。
    ///
    /// | 情況 | 顯示 |
    /// |---|---|
    /// | 各組相同 | `3 × 10`（組數 × 次數） |
    /// | 不同、≤4 組 | `12 · 10 · 8`（直接給數值，遞減看數字就知道） |
    /// | 不同、≥5 組 | `5 組 · 遞增`／`遞減`／`各組不同`（一列排 6 個數字沒人讀得完） |
    ///
    /// ⚠️ 不要跟舊的膠囊搞混：舊的是「**重量** × 次數」（`80% × 8`），這裡是「**組數** × 次數」。
    /// 方向也依次數判定（主行整段講次數）；重量的變化用細節行的箭頭表達。
    static func blockSpec(sets: [PlanSet], language: AppLanguage) -> String {
        let reps = sets.map { $0.targetReps ?? 0 }
        guard let first = reps.first else { return "" }
        if reps.allSatisfy({ $0 == first }) {
            return spec(setCount: sets.count, reps: first)
        }
        if sets.count <= 4 {
            return reps.map(String.init).joined(separator: " · ")
        }
        let pairs = zip(reps, reps.dropFirst())
        let key: String
        if pairs.allSatisfy(<) {
            key = "template.block.progressive %lld"
        } else if pairs.allSatisfy(>) {
            key = "template.block.decreasing %lld"
        } else {
            key = "template.block.mixed %lld"
        }
        return String(format: language.localizedString(key, bundle: .module), sets.count)
    }

    /// 細節行接在器材 pill 後面的重量；沒設重量回 nil（那一行就只有 pill）。
    ///
    /// 各組相同就直接印那一個（`60kg` / `80% 最大重量` / `上次+2.5kg`）；
    /// 各組不同用箭頭表示首→末（`60 → 70kg`），這是 19a 自己舉的例子。
    static func blockWeight(sets: [PlanSet], language: AppLanguage, in unit: WeightUnit) -> String? {
        let expressions = sets.map(\.targetWeight)
        let present = expressions.compactMap { $0 }
        guard let firstExpression = present.first, let lastExpression = present.last else { return nil }

        if present.count == expressions.count, expressions.allSatisfy({ $0 == firstExpression }) {
            return weightLabel(firstExpression, language: language, in: unit)
        }
        // 同單位的絕對重量才壓成「60 → 70kg」（單位只印一次）；其他組合各印各的完整標籤，
        // 混用百分比與公斤時才不會變成看不懂的「70 → 85kg」。
        if case .absolute(let from) = firstExpression, case .absolute(let to) = lastExpression,
           from.unit == to.unit, from != to {
            // 兩端都換算成偏好單位再壓；換算後單位必然相同，所以起點只印數字。
            return "\(Weight.formatted(from.converted(to: unit).value)) → \(to.displayString(in: unit))"
        }
        guard firstExpression != lastExpression else { return weightLabel(firstExpression, language: language, in: unit) }
        return "\(weightLabel(firstExpression, language: language, in: unit)) → \(weightLabel(lastExpression, language: language, in: unit))"
    }

    /// 重量一律帶單位（「20kg」）：kg 與 lb 的 20 差很多。百分比不是重量，沒有單位。
    /// `unit`：呼叫端傳 `@Environment(\.weightDisplayUnit)`，換算成偏好單位再印。
    static func weightLabel(_ expression: WeightExpression, language: AppLanguage, in unit: WeightUnit) -> String {
        switch expression {
        case .absolute(let weight):
            weight.displayString(in: unit)
        case .relativeToLast(let delta):
            String(format: language.localizedString("plan.weight.relativeToLast %@", bundle: .module),
                   (delta.value >= 0 ? "+" : "") + delta.displayString(in: unit))
        case .percentOfMax(let percent):
            String(format: language.localizedString("plan.weight.percentOfMax %@", bundle: .module),
                   "\(Weight.formatted(percent))%")
        }
    }

    /// 當日課表的區塊標題，例：`8 / 15 週五`（設計稿 `22h`）。
    /// 星期依 `locale` 取當地縮寫（由 View 傳 `@Environment(\.locale)`）。
    static func dayLabel(_ day: DayDate, locale: Locale) -> String {
        var components = DateComponents()
        components.year = day.year; components.month = day.month; components.day = day.day
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        var suffix = ""
        if let date = cal.date(from: components) {
            let formatter = DateFormatter()
            formatter.locale = locale
            let weekday = cal.component(.weekday, from: date)
            suffix = " \(formatter.shortWeekdaySymbols[(weekday - 1) % 7])"
        }
        return "\(day.month) / \(day.day)\(suffix)"
    }
}

extension DayDate {
    /// 與 Foundation Date 互轉（給 SwiftUI DatePicker 用）。
    public var asDate: Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }
}
