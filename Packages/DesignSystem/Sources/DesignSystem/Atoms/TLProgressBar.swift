import SwiftUI

/// L1 原子。水平進度條。
///
/// 規格：`design-system/atoms/TLProgressBar/TLProgressBar.spec.md`
///
/// 軌道色是 prop 而不是固定值：這個元件會疊在深淺不同的底上，
/// 軌道要跟所在的底**有對比**——淺底上更深（預設的 `surfaceTrack`）、
/// 深底上更淺（長期課表詳情那張 `neutral-300` 的卡）。寫死會讓它在其中一種底上整條消失。
public struct TLProgressBar: View {
    private let ratio: Double
    private let track: Color

    public init(ratio: Double, track: Color = TLColor.surfaceTrack) {
        self.ratio = ratio
        self.track = track
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(TLColor.actionPrimary)
                    .frame(width: geo.size.width * min(1, max(0, ratio)))
            }
        }
        .frame(height: TLSize.progressBar)
    }
}
