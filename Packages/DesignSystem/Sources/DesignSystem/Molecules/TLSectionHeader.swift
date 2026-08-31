import SwiftUI

/// 模板 2：區塊標題（kicker 樣式）。
/// 10.5pt、weight 600、大寫、字距 0.16em、`neutral-500`。
/// 可選右側文字動作（`accent-700`）。**不加底色、不加圖示。** 下方 margin 10。
/// 可選 `tint`：預設 `neutral-500`；循環／長期「進行中」區用 `accent-600`。
///
/// 文字吃 `Text`（見 TLPageHeader 說明）。
public struct TLSectionHeader: View {
    private let title: Text
    private let tint: Color
    private let trailing: Text?
    private let action: (label: Text, handler: () -> Void)?

    /// 右側可以放一段**唯讀文字**（例如月份區塊的「共 12 小時」）。
    /// 原本右側只開放給按鈕，於是需要放文字的地方只能自己重畫一次 kicker——
    /// 那正是漂移的來源（同一個區塊標題長出第二份實作）。
    public init(_ title: Text, tint: Color = TLColor.neutral500, trailing: Text? = nil) {
        self.title = title
        self.tint = tint
        self.trailing = trailing
        self.action = nil
    }

    public init(_ title: Text, tint: Color = TLColor.neutral500, actionLabel: Text, action: @escaping () -> Void) {
        self.title = title
        self.tint = tint
        self.trailing = nil
        self.action = (actionLabel, action)
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            title
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(tint)
            Spacer(minLength: 0)
            if let trailing {
                trailing
                    .font(TLFont.zh(TLFont.kicker, .semibold))
                    .tracking(TLFont.kickerTracking)
                    .foregroundStyle(tint)
            }
            if let action {
                Button(action: action.handler) { action.label }
                    .buttonStyle(.tlText)
            }
        }
        .padding(.bottom, TLSpace.sectionHeaderGap)
    }
}
