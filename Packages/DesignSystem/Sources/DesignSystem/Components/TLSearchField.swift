import SwiftUI

/// 搜尋列：capsule、`neutral-100` 底、左側放大鏡＋`TextField`。
/// 取代原生 `.searchable`（那顆會掛在 nav bar，且無法套設計稿的膠囊樣式）。
///
/// placeholder 吃 `Text`（呼叫端用 `localText(...)` 建，才對得到 bundle、切語言即時重繪）。
public struct TLSearchField: View {
    @Binding private var text: String
    private let placeholder: Text

    public init(text: Binding<String>, placeholder: Text) {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: TLSpace.gapS) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(TLColor.neutral500)
            let field = TextField("", text: $text, prompt: placeholder.foregroundColor(TLColor.neutral500))
                .font(TLFont.zh(TLFont.rowTitle))
                .foregroundStyle(TLColor.text)
                .autocorrectionDisabled()
            #if os(iOS)
            field.textInputAutocapitalization(.never)
            #else
            field
            #endif
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(TLColor.neutral400)
                }
                .buttonStyle(.plain)
                // 只有 SF Symbol 沒有文字，UITest 沒有東西可以定位；給個穩定 id。
                .accessibilityIdentifier("searchField.clear")
            }
        }
        .padding(.horizontal, TLSpace.rowInset)
        .frame(height: TLSize.row)
        .background(Capsule().fill(TLColor.neutral100))
    }
}
