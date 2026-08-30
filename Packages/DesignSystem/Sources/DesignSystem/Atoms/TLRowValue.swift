import SwiftUI

/// 右側數值 meta：數字用 Caprasimo，可選單位（15pt、neutral-700）。
/// 例：`TLRowValue("62.5", unit: "kg")`、`TLRowValue("3 × 8")`。
public struct TLRowValue: View {
    private let value: String
    private let unit: String?
    public init(_ value: String, unit: String? = nil) {
        self.value = value
        self.unit = unit
    }
    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TLSpace.valueUnitGap) {
            Text(value)
                .font(TLFont.display(TLFont.rowNumber))
                .foregroundStyle(TLColor.text)
            if let unit {
                Text(unit)
                    .font(TLFont.zh(TLFont.rowTitle))
                    .foregroundStyle(TLColor.textBody)
            }
        }
    }
}
