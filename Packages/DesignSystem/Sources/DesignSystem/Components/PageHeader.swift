import SwiftUI

/// 模板 1：頁面主標。
/// 左齊 34pt 主標（允許兩行）。三種變體共用同一 API：
///  - 純標題：`PageHeader("動作庫")`
///  - 標題＋右側 44pt 圓鈕：`PageHeader("動作庫") { CircleIconButton(systemImage: "plus") { … } }`
///  - 標題上方 kicker：`PageHeader("今天練什麼", kicker: "7 / 26 週日 · 3 個計畫進行中")`
///
/// padding：水平 26、頂部 22。
public struct PageHeader<Accessory: View>: View {
    private let title: String
    private let kicker: String?
    private let accessory: Accessory

    public init(
        _ title: String,
        kicker: String? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.kicker = kicker
        self.accessory = accessory()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let kicker {
                Text(kicker)
                    .font(TLFont.zh(TLFont.kicker, .semibold))
                    .tracking(TLFont.kickerTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(TLColor.accent600)
            }
            HStack(alignment: .firstTextBaseline, spacing: TLSpace.gapM) {
                Text(title)
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
