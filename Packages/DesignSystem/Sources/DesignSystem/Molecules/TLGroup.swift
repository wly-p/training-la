import SwiftUI

/// 群組容器：圓角 28 + `neutral-100` 底 + 列間分隔線（頭尾不畫線）。
/// 取代原生 List／Form 的底框。`TLListRow` 與 `TLSettingsRow` 都放進這裡。
public struct TLGroup<Content: View>: View {
    private let border: Color?
    private let content: Content

    /// `border` 用來標「這一區是進行中的」（循環清單）。
    /// 原本呼叫端只能自己在外面疊一個 `strokeBorder` 的 overlay——那是同一件事的第二份實作。
    public init(border: Color? = nil, @ViewBuilder content: () -> Content) {
        self.border = border
        self.content = content()
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous)
    }

    public var body: some View {
        TLDividedVStack {
            content
        }
        .background(TLColor.neutral100)
        .clipShape(shape)
        .overlay {
            if let border {
                shape.strokeBorder(border, lineWidth: TLSize.hairlineThick)
            }
        }
    }
}
