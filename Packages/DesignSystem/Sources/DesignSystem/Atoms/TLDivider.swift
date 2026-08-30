import SwiftUI

/// 列間分隔線：1px、`divider` 色、左內縮 18（＝列內 padding）。
/// 設計規則：只出現在列與列之間，群組容器最上／最下不畫線。
public struct TLDivider: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(TLColor.divider)
            .frame(height: TLSize.hairline)
            .padding(.leading, TLSpace.rowInset)
    }
}
