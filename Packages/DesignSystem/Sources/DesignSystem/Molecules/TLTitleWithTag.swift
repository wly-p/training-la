import SwiftUI

/// 動作名 ＋ 緊跟在後的器材小標。
///
/// ⚠️ 這是**單一動作**的標頭排法（訓練中、預覽 sheet、歷史詳情、能力值四處）。
/// **清單列不要用它**：動作庫的器材在尾欄（`18b`）、範本的在細節行（`19a`），
/// 因為 pill 跟著名稱浮動時左緣每列不同，整份清單會出現鋸齒。
///
/// 規則寫成元件而不是散在各畫面，是因為它有兩個容易做錯的細節：
/// 名稱要 `lineLimit(1)` + tail truncate、而 pill 要靠 `layoutPriority` 保住不被壓縮。
/// 沒有這兩個，長名稱會把 pill 擠掉或推到第二行。
///
/// 字體與顏色由呼叫端先套在 `title` 上（大標題 28pt、列 15pt 各有各的）。
public struct TLTitleWithTag: View {
    private let title: Text
    private let equipment: String

    public init(title: Text, equipment: String) {
        self.title = title
        self.equipment = equipment
    }

    /// 動作名是使用者資料，不本地化。
    public init(name: String, equipment: String, font: Font = TLFont.zh(TLFont.rowTitle, .semibold)) {
        self.init(title: Text(verbatim: name).font(font).foregroundColor(TLColor.text), equipment: equipment)
    }

    public var body: some View {
        HStack(spacing: 8) {
            title
                .lineLimit(1)
                .truncationMode(.tail)
            TLEquipmentTag(equipment)
                .layoutPriority(1)
        }
    }
}
