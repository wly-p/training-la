import SwiftUI

/// 設定列右側的值文字（14pt weight 500、`neutral-600`）。搭配 `showChevron: true` 呈現「值＋chevron」。
/// 比標題小一號、比 chevron 深一階：值是列的答案，不該跟標題一樣重，也不該淡到讀不到。
public struct TLSettingsValue: View {
    private let text: Text
    public init(_ text: Text) { self.text = text }
    public var body: some View {
        text
            .font(TLFont.zh(TLFont.rowValue))
            .foregroundStyle(TLColor.neutral600)
    }
}
