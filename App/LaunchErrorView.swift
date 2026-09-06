import DesignSystem
import SharedKernel
import SwiftUI

struct LaunchErrorView: View {
    let error: Error
    let onRetry: @MainActor () -> Void

    var body: some View {
        ZStack {
            TLColor.bg
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(TLColor.accent)

                    Text(LocalizedStringKey("launch.error.title"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TLColor.text)

                    Text(LocalizedStringKey("launch.error.message"))
                        .font(.system(size: 14))
                        .foregroundStyle(TLColor.textSecondary)
                        .multilineTextAlignment(.center)

                    // 技術性錯誤內容降級成次要說明，不完全捨棄除錯資訊。
                    Text(verbatim: error.localizedDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(TLColor.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)

                Spacer()

                Button(action: onRetry) {
                    Text(LocalizedStringKey("launch.error.retry"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .background(TLColor.accent)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

#Preview {
    LaunchErrorView(
        error: NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize data layer"]),
        onRetry: {}
    )
}
