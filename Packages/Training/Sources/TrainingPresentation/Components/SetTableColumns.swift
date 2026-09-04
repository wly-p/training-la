import DesignSystem
import SharedKernel
import SwiftUI
import TrainingDomain

/// 組表一列（表頭或資料列）的欄位排版：組欄固定寬靠左，剩下的寬度平分給目標／實際，兩欄各自靠右。
///
/// 表頭與資料列共用它 —— 兩邊各寫一次的話，欄寬遲早對不齊。
struct SetTableColumns<Index: View, Target: View, Actual: View>: View {
    let index: Index
    let target: Target
    let actual: Actual

    init(
        @ViewBuilder index: () -> Index,
        @ViewBuilder target: () -> Target,
        @ViewBuilder actual: () -> Actual
    ) {
        self.index = index()
        self.target = target()
        self.actual = actual()
    }

    var body: some View {
        HStack(spacing: TLSpace.setColumnGap) {
            index.frame(width: TLSize.setIndexColumnNarrow, alignment: .leading)
            target.frame(maxWidth: .infinity, alignment: .trailing)
            actual.frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
