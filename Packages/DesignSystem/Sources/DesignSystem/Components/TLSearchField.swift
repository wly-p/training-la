import SwiftUI

/// 搜尋列：capsule、`neutral-100` 底、左側放大鏡＋`TextField`。
/// 取代原生 `.searchable`（那顆會掛在 nav bar，且無法套設計稿的膠囊樣式）。
///
/// placeholder 吃 `Text`（呼叫端用 `localText(...)` 建，才對得到 bundle、切語言即時重繪）。
public struct TLSearchField: View {
    @Binding private var text: String
    private let placeholder: Text
    /// UITest 定位用（見 ARCHITECTURE.md 的命名規範）。
    ///
    /// 由呼叫端給、而不是全部共用一個固定值：動作庫清單與選動作 picker 的搜尋列
    /// 長得一模一樣，而 picker 以 sheet 疊在清單上時**兩個都在無障礙樹裡**，
    /// 共用 id 會讓測試打到背後那一個。
    private let identifier: String

    public init(text: Binding<String>, placeholder: Text, identifier: String) {
        self._text = text
        self.placeholder = placeholder
        self.identifier = identifier
    }

    public var body: some View {
        HStack(spacing: TLSpace.gapS) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(TLColor.neutral500)
            let field = TextField(text: $text, prompt: placeholder.foregroundColor(TLColor.neutral500)) { Text(verbatim: "") }
                .font(TLFont.zh(TLFont.rowTitle))
                .foregroundStyle(TLColor.text)
                .autocorrectionDisabled()
                .accessibilityIdentifier(identifier)
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
                .accessibilityIdentifier("\(identifier).clear")
            }
        }
        .padding(.horizontal, TLSpace.rowInset)
        .frame(height: TLSize.row)
        .background(Capsule().fill(TLColor.neutral100))
    }
}
