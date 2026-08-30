import SwiftUI

/// 器材小標（handoff-15 B 節）。`sage-200` 底 + `sage-900` 字、10.5pt weight 600、
/// padding 5×9、pill。
///
/// 跟 ``TLMuscleTag`` 同一個綠但更小、更輕：肌群是使用者會去點的篩選 chip，
/// 器材只是跟在動作名旁邊的 metadata。**不用 accent（terracotta）**——那是主行動色。
///
/// 存在的理由是動作名允許重複（肩推有槓鈴／啞鈴／機械三筆），
/// 名稱不塞器材前綴，改用這個標來分辨（見 `docs/exercise-glossary.md`）。
///
/// 擺放位置有兩種，依畫面而定：
///   - **尾欄**（動作庫 `18b`）：列的右緣、靠右對齊。分組依據不在列上重複，所以按器材分組時
///     這個位置改放**肌群**——同一個尾欄、同一個 pill 形狀，只是內容換掉，故 `identifier` 可換。
///   - **細節行**（範本 `19a`）：退到第二行、與名稱共用左緣。
///   - 名稱右側（訓練中、預覽 sheet、歷史詳情、能力值）：見 ``TLTitleWithTag``。
public struct TLEquipmentTag: View {
    private let label: String
    private let identifier: String

    /// - Parameter identifier: 尾欄放肌群時傳 `"muscleTag"`，UITest 才分得出這一列現在標的是什麼。
    public init(_ label: String, identifier: String = "equipmentTag") {
        self.label = label
        self.identifier = identifier
    }

    public var body: some View {
        Text(label)
            .font(TLFont.zh(TLFont.kicker, .semibold))
            .foregroundStyle(TLColor.sage900)
            .lineLimit(1)
            .fixedSize()               // 永不縮小、永不換行——空間不足時該被 truncate 的是動作名
            .padding(.vertical, TLSpace.tagPadV)
            .padding(.horizontal, TLSpace.tagPadH)
            .background(Capsule().fill(TLColor.sage200))
            // 標籤文字會跟著 app 語言換，測試只驗「這一列掛的是哪一種標」，內容正確性歸 unit test。
            .accessibilityIdentifier(identifier)
    }
}
