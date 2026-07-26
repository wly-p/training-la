import SwiftUI

/// 模板 2：區塊標題（kicker 樣式）。
/// 10.5pt、weight 600、大寫、字距 0.16em、`neutral-500`。
/// 可選右側文字動作（`accent-700`）。**不加底色、不加圖示。** 下方 margin 10。
///
/// 文字吃 `Text`（見 PageHeader 說明）。
public struct SectionHeader: View {
    private let title: Text
    private let action: (label: Text, handler: () -> Void)?

    public init(_ title: Text) {
        self.title = title
        self.action = nil
    }

    public init(_ title: Text, actionLabel: Text, action: @escaping () -> Void) {
        self.title = title
        self.action = (actionLabel, action)
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            title
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(TLColor.neutral500)
            Spacer(minLength: 0)
            if let action {
                Button(action: action.handler) { action.label }
                    .buttonStyle(.tlText)
            }
        }
        .padding(.bottom, 10)
    }
}
