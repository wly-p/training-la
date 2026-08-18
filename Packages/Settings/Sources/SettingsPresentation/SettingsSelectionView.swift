import DesignSystem
import SwiftUI

/// drill-in 選擇子畫面（主題／語言／App 圖示共用）。
/// 設計稿未畫這層 → 用 DesignSystem 風格自建：返回鈕＋`PageHeader`＋`TLGroup` 選項清單，
/// 目前選中者右側打勾。點選即更新並自動返回。
struct SettingsSelectionView<Value: Hashable & Identifiable>: View {
    let title: Text
    let options: [Value]
    let current: Value
    /// 選項顯示文字（用 `localText` 或 `Text(verbatim:)` 建）。
    let label: (Value) -> Text
    /// 選項左側預覽圖 asset 名（App 圖示用）；nil＝不顯示。
    let leadingImageName: ((Value) -> String)?
    /// 選取選項；由父層更新值並清掉 route（＝pop 回根頁）。
    let onSelect: (Value) -> Void
    /// 返回（不選）；父層清 route。
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                backBar
                PageHeader(title)
                TLGroup {
                    ForEach(options) { option in
                        row(for: option)
                    }
                }
                .padding(.horizontal, TLSpace.page)
                .padding(.top, TLSpace.section)
            }
            .padding(.bottom, 40)
        }
        .background(TLColor.bg.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var backBar: some View {
        HStack {
            CircleIconButton(systemImage: "chevron.left", filled: false) { onBack() }
                .accessibilityLabel(localText("settings.common.back"))
            Spacer()
        }
        .padding(.horizontal, TLSpace.page)
        .padding(.top, 12)
    }

    /// 選項的 id 由 `Identifiable.id` 推出來（`AppTheme` / `AppLanguage` / `AppIcon` 的
    /// `id` 都是 rawValue），所以測試點「深色」是 `settings.option.dark`，跟顯示文字無關。
    private func identifier(for option: Value) -> String {
        "settings.option.\(option.id)"
    }

    private func row(for option: Value) -> some View {
        ListRow(
            title: label(option),
            showChevron: false,
            onTap: {
                onSelect(option)
            },
            leading: {
                if let leadingImageName {
                    Image(leadingImageName(option))
                        .resizable()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            },
            trailing: {
                if option == current {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TLColor.accent)
                }
            }
        )
        .accessibilityIdentifier(identifier(for: option))
    }
}
