import SwiftUI

/// 22pt 赭紅圓形勾（可勾選列）。
public struct TLCheckCircle: View {
    private let isChecked: Bool
    public init(isChecked: Bool) { self.isChecked = isChecked }
    public var body: some View {
        ZStack {
            Circle()
                .fill(isChecked ? TLColor.accent : Color.clear)
                .overlay(Circle().strokeBorder(isChecked ? Color.clear : TLColor.neutral400, lineWidth: TLSize.hairlineThick))
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: TLIcon.inCheckCircle, weight: .bold))
                    .foregroundStyle(TLColor.bg)
            }
        }
        .frame(width: TLSize.checkCircle, height: TLSize.checkCircle)
    }
}
