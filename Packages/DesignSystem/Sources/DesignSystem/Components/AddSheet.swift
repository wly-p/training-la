import SwiftUI

/// 「+」新增選單（設計稿 10a）。bottom sheet：標題「新增什麼」＋副標，四列各帶圖示圓章與說明；
/// 當前分頁那列 `accent-100` 底＋`accent` 圓章＋「目前分頁」標籤。
/// 圓章一律用**圖示**（設計原則 10：沒有實體數量的地方不用數字章）。
///
/// 用 `.sheet` 呈現，建議搭 `.presentationDetents([.height(...)])`。文字吃 `Text`（呼叫端 localText 建）。
public struct AddSheet: View {
    public struct Item: Identifiable {
        public let id: String
        public let systemImage: String
        public let title: Text
        public let subtitle: Text
        public let isCurrent: Bool
        public let action: () -> Void
        public init(
            id: String,
            systemImage: String,
            title: Text,
            subtitle: Text,
            isCurrent: Bool = false,
            action: @escaping () -> Void
        ) {
            self.id = id
            self.systemImage = systemImage
            self.title = title
            self.subtitle = subtitle
            self.isCurrent = isCurrent
            self.action = action
        }
    }

    private let title: Text
    private let subtitle: Text
    private let currentTag: Text
    private let items: [Item]

    public init(title: Text, subtitle: Text, currentTag: Text, items: [Item]) {
        self.title = title
        self.subtitle = subtitle
        self.currentTag = currentTag
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
                .font(TLFont.zh(TLFont.cardTitle, .bold))
                .foregroundStyle(TLColor.text)
            subtitle
                .font(TLFont.zh(TLFont.rowSub, .regular))
                .foregroundStyle(TLColor.neutral500)
                .padding(.top, 4)

            TLGroup {
                ForEach(items) { item in
                    row(item)
                }
            }
            .padding(.top, TLSpace.gapL)
        }
        .padding(.horizontal, TLSpace.page)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TLColor.bg)
    }

    private func row(_ item: Item) -> some View {
        Button(action: item.action) {
            HStack(spacing: TLSpace.gapM) {
                CircleBadge(
                    icon: item.systemImage,
                    fill: item.isCurrent ? TLColor.accent : TLColor.neutral200,
                    tint: item.isCurrent ? TLColor.bg : TLColor.neutral600
                )
                VStack(alignment: .leading, spacing: 2) {
                    item.title
                        .font(TLFont.zh(TLFont.rowTitle))
                        .foregroundStyle(TLColor.text)
                    item.subtitle
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                        .lineLimit(1)
                }
                Spacer(minLength: TLSpace.gapS)
                if item.isCurrent {
                    currentTag
                        .font(TLFont.zh(TLFont.rowSub, .semibold))
                        .foregroundStyle(TLColor.accent700)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(TLColor.accent200))
                }
            }
            .padding(.horizontal, TLSpace.rowInset)
            .frame(minHeight: TLSize.rowWithSub)
            .contentShape(Rectangle())
            .background(item.isCurrent ? TLColor.accent100 : Color.clear)
        }
        .buttonStyle(RowPressStyle())
    }
}
