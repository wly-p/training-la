import DesignSystem
import SwiftUI

/// drill-in 選擇子畫面（主題／語言／App 圖示共用）。
/// 設計稿未畫這層 → 用 DesignSystem 風格自建：返回鈕＋`TLPageHeader`＋`TLGroup` 選項清單，
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
                TLPageHeader(title)
                TLGroup {
                    ForEach(options) { option in
                        row(for: option)
                    }
                }
                .padding(.horizontal, TLSpace.page)
                .padding(.top, TLSpace.section)
            }
            .padding(.bottom, TLSpace.pageBottom)
        }
        .background(TLColor.bg.ignoresSafeArea())
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var backBar: some View {
        TLBackBar(onBack: onBack)
    }

    /// 選項的 id 由 `Identifiable.id` 推出來（`AppTheme` / `AppLanguage` / `AppIcon` 的
    /// `id` 都是 rawValue），所以測試點「深色」是 `settings.option.dark`，跟顯示文字無關。
    private func identifier(for option: Value) -> String {
        "settings.option.\(option.id)"
    }

    private func row(for option: Value) -> some View {
        TLListRow(
            title: label(option),
            showChevron: false,
            onTap: {
                onSelect(option)
            },
            leading: {
                if let leadingImageName {
                    TLIconThumbnail(imageName: leadingImageName(option))
                }
            },
            trailing: {
                if option == current {
                    Image(systemName: "checkmark")
                        .font(.system(size: TLIcon.inline, weight: .bold))
                        .foregroundStyle(TLColor.accent)
                }
            }
        )
        .accessibilityIdentifier(identifier(for: option))
    }
}
