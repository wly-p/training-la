import Foundation
import SharedKernel
import Testing
import TrainingDomain

@testable import TrainingPresentation

struct WeightSourceFormattingTests {
    /// 固定用繁中解析，不讓結果隨執行機器的語系飄。
    private let zhHant = Locale(identifier: "zh-Hant")

    /// 標籤本身用同一支 helper 取，不在測試裡寫死中文。
    ///
    /// 原因：`swift test` 走 SwiftPM，而 SwiftPM **不編譯 String Catalog**（只有 Xcode 會把
    /// `.xcstrings` 轉成 `xx.lproj/Localizable.strings`），所以這裡查表一律回 key 本身。
    /// 寫死中文的話這幾條就只是在測「原始碼裡的字面值」，換成查表後必然失敗——
    /// 真正該守住的是**組裝邏輯**：標籤、數值、正負號、強度後綴的順序與有無。
    private func label(_ key: String) -> String { localString(key, zhHant) }

    @Test func absoluteWithBaselineIntensityHasNoAlgebraLine() {
        let source = TargetWeightSource(kind: .absolute, base: Weight(value: 60, unit: .kg), intensityFactor: 1.0)
        #expect(WeightSourceFormatting.algebraText(source, locale: zhHant) == nil)
    }

    @Test func absoluteWithIntensityShowsBaseTimesFactor() {
        let source = TargetWeightSource(kind: .absolute, base: Weight(value: 120, unit: .kg), intensityFactor: 0.75)
        #expect(WeightSourceFormatting.algebraText(source, locale: zhHant) == "120kg × 75%")
    }

    @Test func percentOf1RMResolvedShowsPercentTimesFactorAndAbility() {
        let source = TargetWeightSource(
            kind: .percentOfMax, percent: 80, abilityValue: Weight(value: 140, unit: .kg), intensityFactor: 0.75
        )
        #expect(
            WeightSourceFormatting.algebraText(source, locale: zhHant)
                == "80% · × 75% · \(label("training.weightSource.maxWeightLabel")) 140kg"
        )
    }

    @Test func percentOf1RMAtBaselineOmitsFactorSuffix() {
        let source = TargetWeightSource(
            kind: .percentOfMax, percent: 80, abilityValue: Weight(value: 140, unit: .kg), intensityFactor: 1.0
        )
        #expect(
            WeightSourceFormatting.algebraText(source, locale: zhHant)
                == "80% · \(label("training.weightSource.maxWeightLabel")) 140kg"
        )
    }

    @Test func percentOf1RMUnresolvedHasNoAlgebraButHasReason() {
        let source = TargetWeightSource(kind: .percentOfMax, percent: 80, abilityValue: nil, intensityFactor: 1.0)
        #expect(WeightSourceFormatting.algebraText(source, locale: zhHant) == nil)
        #expect(WeightSourceFormatting.unresolvedReason(source, locale: zhHant) != nil)
    }

    @Test func relativeToLastResolvedShowsLastPlusDelta() {
        let source = TargetWeightSource(
            kind: .relativeToLast, delta: Weight(value: 2.5, unit: .kg), lastWeight: Weight(value: 45, unit: .kg),
            intensityFactor: 0.75
        )
        #expect(
            WeightSourceFormatting.algebraText(source, locale: zhHant)
                == "\(label("training.weightSource.lastLabel")) 45kg +2.5kg · × 75%"
        )
    }

    @Test func relativeToLastUnresolvedHasNoAlgebraButHasReason() {
        let source = TargetWeightSource(kind: .relativeToLast, delta: Weight(value: 2.5, unit: .kg), lastWeight: nil, intensityFactor: 1.0)
        #expect(WeightSourceFormatting.algebraText(source, locale: zhHant) == nil)
        #expect(WeightSourceFormatting.unresolvedReason(source, locale: zhHant) != nil)
    }

    @Test func noExpressionHasNoAlgebraButHasReason() {
        let source = TargetWeightSource(kind: .none, intensityFactor: 1.0)
        #expect(WeightSourceFormatting.algebraText(source, locale: zhHant) == nil)
        #expect(WeightSourceFormatting.unresolvedReason(source, locale: zhHant) != nil)
    }

    @Test func nilSourceHasNoAlgebraAndNoReason() {
        #expect(WeightSourceFormatting.algebraText(nil, locale: zhHant) == nil)
        #expect(WeightSourceFormatting.unresolvedReason(nil, locale: zhHant) == nil)
    }

    @Test func intensityPillOmittedAtBaseline() {
        #expect(WeightSourceFormatting.intensityPillText(1.0) == nil)
        #expect(WeightSourceFormatting.intensityPillText(0.75) == "×75%")
    }
}
