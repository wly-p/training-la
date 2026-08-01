import Foundation
import PlanDomain
import SharedKernel
import Testing

@testable import PlanData

/// `percentOfMax` 的 Swift 名在 handoff-15 從 `percentOf1RM` 改過來，
/// 但**儲存字串必須維持舊值**——它落在 SwiftData 欄位與 WeightSourceInfo 的 JSON 快照裡，
/// 改了等於讓既有使用者的排課全部解不出來。這幾個測試就是守這條線。
struct WeightExpressionCodingTests {
    @Test func percentOfMaxStillEncodesAsLegacyString() {
        let (kind, value, unit) = WeightExpressionCoding.encode(.percentOfMax(80))
        #expect(kind == "percentOf1RM")
        #expect(value == 80)
        #expect(unit == nil)
    }

    @Test func decodesLegacyString() {
        #expect(WeightExpressionCoding.decode(kind: "percentOf1RM", value: 80, unitRaw: nil) == .percentOfMax(80))
    }

    /// 新字串也收——之後若有人真的改寫了資料，不要因此解不出來。
    @Test func decodesNewStringToo() {
        #expect(WeightExpressionCoding.decode(kind: "percentOfMax", value: 80, unitRaw: nil) == .percentOfMax(80))
    }

    @Test func weightSourceKindKeepsLegacyRawValue() {
        #expect(WeightSourceInfo.Kind.percentOfMax.rawValue == "percentOf1RM")
        #expect(WeightSourceInfo.Kind(rawValue: "percentOf1RM") == .percentOfMax)
    }

    @Test func absoluteAndRelativeRoundTrip() {
        let absolute = WeightExpression.absolute(Weight(value: 60, unit: .kg))
        let (k1, v1, u1) = WeightExpressionCoding.encode(absolute)
        #expect(WeightExpressionCoding.decode(kind: k1, value: v1, unitRaw: u1) == absolute)

        let relative = WeightExpression.relativeToLast(delta: Weight(value: 2.5, unit: .lb))
        let (k2, v2, u2) = WeightExpressionCoding.encode(relative)
        #expect(WeightExpressionCoding.decode(kind: k2, value: v2, unitRaw: u2) == relative)
    }
}
