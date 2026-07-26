import SwiftUI

/// 模板 1：頁面主標。
/// 左齊 34pt 主標（允許兩行）。三種變體共用同一 API：
///  - 純標題：`PageHeader(localText("settings.title"))`
///  - 標題＋右側 44pt 圓鈕：`PageHeader(...) { CircleIconButton(systemImage: "plus") { … } }`
///  - 標題上方 kicker：`PageHeader(..., kicker: localText("..."))`
///
/// 文字吃 `Text`（不是 `String`）：呼叫端用各 package 的 `localText(key)`＝`Text(key, bundle:.module)`
/// 建好再傳進來，才對得到該 package 的 String Catalog、且切語言即時重繪。
///
/// padding：水平 26、頂部 22。
public struct PageHeader<Accessory: View>: View {
    private let title: Text
    private let kicker: Text?
    private let accessory: Accessory

    public init(
        _ title: Text,
        kicker: Text? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.kicker = kicker
        self.accessory = accessory()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let kicker {
                kicker
                    .font(TLFont.zh(TLFont.kicker, .semibold))
                    .tracking(TLFont.kickerTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(TLColor.accent600)
            }
            HStack(alignment: .firstTextBaseline, spacing: TLSpace.gapM) {
                title
                    .font(TLFont.zh(TLFont.pageTitle, .bold))
                    .tracking(TLFont.pageTitle * -0.02)   // tracking -0.02em
                    .foregroundStyle(TLColor.text)
                    .lineLimit(2)                          // 主標允許兩行
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                accessory
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
            }
        }
        .padding(.horizontal, TLSpace.page)
        .padding(.top, 22)
    }
}
