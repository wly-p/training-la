import DesignSystem
import SwiftUI

/// L3 有機體。訓練中「接下來」的一列（11c E）。
///
/// 規格：`design-system/organisms/UpNextRow/UpNextRow.spec.md`
///
/// **刻意不套 `TLGroup`**：設計稿是直接排在頁面底色上、只用細線分隔 ——
/// 卡片底會讓它看起來跟上面的組表同一個層級，但它只是待辦清單。
struct UpNextRow: View {
    let name: String
    let isCurrent: Bool
    /// 右側目標「3 × 10 · 24 kg」；自由加練沒有課表目標＝nil。
    let target: String?
    let onSelect: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: TLSpace.gapM) {
                Text(verbatim: name)
                    .font(TLFont.zh(TLFont.rowTitle, isCurrent ? .semibold : .regular))
                    .foregroundStyle(TLColor.text)
                Spacer(minLength: TLSpace.gapS)
                if let target {
                    Text(verbatim: target)
                        .font(TLFont.display(13.5))
                        .foregroundStyle(TLColor.neutral500)
                }
            }
            .padding(.vertical, TLSpace.fieldPadV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 長按該列＝對這個動作開中途改課（13e）——設計稿「長按可換動作」。
        .onLongPressGesture(minimumDuration: 0.4, perform: onLongPress)
        .accessibilityIdentifier("activeWorkout.midWorkoutEdit")
    }
}
