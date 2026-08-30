import SwiftUI

/// L1 原子。可進入的列右側的指向記號。
///
/// 規格：`design-system/atoms/TLChevron/TLChevron.spec.md`
///
/// 沒有 props——它的尺寸與顏色是固定的，位置與間距由使用它的列負責。
/// 方向由系統處理：SF Symbol 的 `chevron.right` 在 RTL 語系自動鏡射。
public struct TLChevron: View {
    public init() {}

    public var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(TLColor.textTertiary)
    }
}
