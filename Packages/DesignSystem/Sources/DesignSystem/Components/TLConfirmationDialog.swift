import SwiftUI

/// 自訂確認對話框（取代原生 `.alert`／`.confirmationDialog`）。
/// `neutral-100` 底、圓角 32、`shadow-lg`、垂直置中、左右各距螢幕 24pt；文案靠左。
///
/// 按鈕配色依 `role`（handoff-20 E 節）：
///   - `.destructive`：確認＝外框 danger（在上）／取消＝`accent` 實心。**填色給安全的那一顆**。
///   - `.normal`：確認＝實心 accent／取消＝線框（照舊）。
///
/// 用法：
/// ```
/// someView.tlConfirmationDialog(
///     isPresented: $showConfirm,
///     title: localText("..."), message: localText("..."),
///     confirmLabel: localText("..."), cancelLabel: localText("..."),
///     confirmIdentifier: "eraseConfirmButton",
///     onConfirm: { … }
/// )
/// ```
public enum TLDialogRole { case normal, destructive }

private struct TLConfirmationDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: Text
    let message: Text
    let confirmLabel: Text
    let cancelLabel: Text
    let role: TLDialogRole
    let confirmIdentifier: String?
    let cancelIdentifier: String?
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                dialog
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isPresented)
    }

    private var dialog: some View {
        ZStack {
            Color(hex: 0x201E1D).opacity(0.34)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { isPresented = false }

            VStack(alignment: .leading, spacing: 0) {
                // 文案靠左，不置中：這裡要讀的是後果，不是宣告。置中的長句每行起點都在跳。
                title
                    .font(TLFont.zh(20, .bold))
                    .tracking(-0.2)               // letter-spacing -.01em
                    .foregroundStyle(TLColor.text)
                    .fixedSize(horizontal: false, vertical: true)
                message
                    .font(TLFont.zh(13.5, .regular))
                    .lineSpacing(6)               // 行高 1.65
                    .foregroundStyle(TLColor.neutral700)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.bottom, 20)

                VStack(spacing: 10) {
                    confirmButton
                    cancelButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 26)
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
            .background(TLColor.neutral100)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .tlShadow(TLShadow.lg)
            .padding(.horizontal, 24)
        }
    }

    /// 確認鍵永遠在上（iOS destructive 的慣例位置），但破壞性時它是**外框**——見 `TLDialogDestructiveButtonStyle`。
    @ViewBuilder
    private var confirmButton: some View {
        let action = {
            isPresented = false
            onConfirm()
        }
        if role == .destructive {
            Button(action: action) { confirmLabel }
                .buttonStyle(.tlDialogDestructive)
                .modifier(OptionalIdentifier(id: confirmIdentifier))
        } else {
            Button(action: action) { confirmLabel }
                .buttonStyle(.tlPrimary)
                .modifier(OptionalIdentifier(id: confirmIdentifier))
        }
    }

    /// 破壞性時取消是唯一有填色的一顆；一般對話框維持線框（填色留給上面的主要動作）。
    @ViewBuilder
    private var cancelButton: some View {
        let action = { isPresented = false }
        if role == .destructive {
            Button(action: action) { cancelLabel }
                .buttonStyle(.tlDialogPrimary)
                .modifier(OptionalIdentifier(id: cancelIdentifier))
        } else {
            Button(action: action) { cancelLabel }
                .buttonStyle(.tlSecondary)
                .modifier(OptionalIdentifier(id: cancelIdentifier))
        }
    }
}

/// 選擇性套 accessibilityIdentifier（`nil` 就什麼都不做）。
/// 元件的 identifier 一律由呼叫端決定——同一個元件在不同畫面用，寫死在元件裡就撞名了。
struct OptionalIdentifier: ViewModifier {
    let id: String?
    func body(content: Content) -> some View {
        if let id {
            content.accessibilityIdentifier(id)
        } else {
            content
        }
    }
}

public extension View {
    func tlConfirmationDialog(
        isPresented: Binding<Bool>,
        title: Text,
        message: Text,
        confirmLabel: Text,
        cancelLabel: Text,
        role: TLDialogRole = .destructive,
        confirmIdentifier: String? = nil,
        cancelIdentifier: String? = nil,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(TLConfirmationDialogModifier(
            isPresented: isPresented,
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            cancelLabel: cancelLabel,
            role: role,
            confirmIdentifier: confirmIdentifier,
            cancelIdentifier: cancelIdentifier,
            onConfirm: onConfirm
        ))
    }
}
