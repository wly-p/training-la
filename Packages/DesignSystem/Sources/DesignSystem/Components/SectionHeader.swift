import SwiftUI

/// 模板 2：區塊標題（kicker 樣式）。
/// 10.5pt、weight 600、大寫、字距 0.16em、`neutral-500`。
/// 可選右側文字動作（`accent-700`）。**不加底色、不加圖示。** 下方 margin 10。
public struct SectionHeader: View {
    private let title: String
    private let action: (label: String, handler: () -> Void)?

    public init(_ title: String) {
        self.title = title
        self.action = nil
    }

    public init(_ title: String, actionLabel: String, action: @escaping () -> Void) {
        self.title = title
        self.action = (actionLabel, action)
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(TLColor.neutral500)
            Spacer(minLength: 0)
            if let action {
                Button(action.label, action: action.handler)
                    .buttonStyle(.tlText)
            }
        }
        .padding(.bottom, 10)
    }
}
