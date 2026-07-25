import SwiftUI

/// 列間分隔線：1px、`divider` 色、左內縮 18（＝列內 padding）。
/// 設計規則：只出現在列與列之間，群組容器最上／最下不畫線。
public struct TLDivider: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(TLColor.divider)
            .frame(height: 1)
            .padding(.leading, TLSpace.rowInset)
    }
}

/// 把任意子 View 垂直堆疊，並在「相鄰兩子 View 之間」插入 `TLDivider`。
/// 頭尾不畫線 —— 對應設計規則「容器最上／最下不畫線」。
///
/// 用 `_VariadicView` 解析子 View，才能對「一組異質靜態列」（如設定頁）自動加分隔線，
/// 不必逼呼叫端改成 data-driven 的 ForEach。
public struct DividedVStack<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        _VariadicView.Tree(DividedLayout()) {
            content
        }
    }
}

private struct DividedLayout: _VariadicView_MultiViewRoot {
    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id
        VStack(spacing: 0) {
            ForEach(children) { child in
                child
                if child.id != last {
                    TLDivider()
                }
            }
        }
    }
}
