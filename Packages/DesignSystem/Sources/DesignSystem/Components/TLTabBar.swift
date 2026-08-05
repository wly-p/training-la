import SwiftUI

/// 分頁列（`00-overview.md`）：平放、無膠囊底，5 欄各佔等寬；22pt 圖示 ＋ 10.5pt 標籤；
/// 選中＝`text` 色 weight 700 ＋ 下方 22×3 赭紅底線，未選＝`neutral-500` ＋ 等高空白佔位（維持列高一致）。
/// 容器 padding：左右 20、底 8。
public struct TLTabBar<Value: Hashable>: View {
    public struct Item: Identifiable {
        public let value: Value
        public let systemImage: String
        public let label: Text
        public var id: Value { value }

        public init(_ value: Value, systemImage: String, label: Text) {
            self.value = value
            self.systemImage = systemImage
            self.label = label
        }
    }

    @Binding private var selection: Value
    private let items: [Item]

    public init(selection: Binding<Value>, items: [Item]) {
        self._selection = selection
        self.items = items
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = item.value == selection
                Button {
                    selection = item.value
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 22, weight: .regular))
                        item.label
                            .font(TLFont.zh(TLFont.kicker, isSelected ? .bold : .regular))
                        Capsule()
                            .fill(isSelected ? TLColor.accent : Color.clear)
                            .frame(width: 22, height: 3)
                    }
                    .foregroundStyle(isSelected ? TLColor.text : TLColor.neutral500)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // 原生分頁列被 .toolbar(.hidden, for: .tabBar) 藏起來了，但它仍留在無障礙樹裡，
                // UITest 用 app.tabBars 會抓到那個藏起來的、點了不一定有效。給穩定的 id 讓測試
                // 直接點到這一列，也不必依賴會隨語言變的標籤文字。
                .accessibilityIdentifier("tabBar.item.\(item.value)")
            }
        }
        .padding(.horizontal, TLSpace.gapL)
        .padding(.bottom, TLSpace.gapS)
        .background(TLColor.bg)
    }
}
