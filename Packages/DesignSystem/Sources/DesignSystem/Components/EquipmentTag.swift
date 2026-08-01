import SwiftUI

/// 器材小標（handoff-15 B 節）。`sage-200` 底 + `sage-900` 字、10.5pt weight 600、
/// padding 5×9、pill。
///
/// 跟 ``MuscleTag`` 同一個綠但更小、更輕：肌群是使用者會去點的篩選 chip，
/// 器材只是跟在動作名旁邊的 metadata。**不用 accent（terracotta）**——那是主行動色。
///
/// 存在的理由是動作名允許重複（肩推有槓鈴／啞鈴／機械三筆），
/// 名稱不塞器材前綴，改用這個標來分辨（見 `docs/exercise-glossary.md`）。
public struct EquipmentTag: View {
    private let label: String

    public init(_ label: String) {
        self.label = label
    }

    public var body: some View {
        Text(label)
            .font(TLFont.zh(10.5, .semibold))
            .foregroundStyle(TLColor.sage900)
            .lineLimit(1)
            .fixedSize()               // 永不縮小、永不換行——空間不足時該被 truncate 的是動作名
            .padding(.vertical, 5)
            .padding(.horizontal, 9)
            .background(Capsule().fill(TLColor.sage200))
    }
}

/// 動作名 ＋ 器材小標的標準組合（handoff-15 B 節的擺放規則）。
///
/// 規則寫成元件而不是散在各畫面，是因為它有兩個容易做錯的細節：
/// 名稱要 `lineLimit(1)` + tail truncate、而 pill 要靠 `layoutPriority` 保住不被壓縮。
/// 沒有這兩個，長名稱會把 pill 擠掉或推到第二行。
///
/// 字體與顏色由呼叫端先套在 `title` 上（大標題 28pt、列 15pt 各有各的）。
public struct ExerciseNameWithEquipment: View {
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
            EquipmentTag(equipment)
                .layoutPriority(1)
        }
    }
}
