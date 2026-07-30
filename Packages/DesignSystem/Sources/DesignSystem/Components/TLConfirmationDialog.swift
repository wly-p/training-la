import SwiftUI

/// 自訂確認對話框（取代原生 `.alert`／`.confirmationDialog`）。
/// 設計稿 Interactions：`shadow-lg`、圓角 28、置中、取消＝線框、確認＝實心（破壞性用 danger）。
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
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { isPresented = false }

            VStack(spacing: 14) {
                title
                    .font(TLFont.zh(TLFont.cardTitle, .bold))
                    .foregroundStyle(TLColor.text)
                    .multilineTextAlignment(.center)
                message
                    .font(TLFont.zh(14, .regular))
                    .foregroundStyle(TLColor.neutral600)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    confirmButton
                    Button { isPresented = false } label: { cancelLabel }
                        .buttonStyle(.tlSecondary)
                        .modifier(OptionalIdentifier(id: cancelIdentifier))
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(TLColor.bg)
            .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
            .tlShadow(TLShadow.lg)
            .padding(.horizontal, 40)
        }
    }

    @ViewBuilder
    private var confirmButton: some View {
        let action = {
            isPresented = false
            onConfirm()
        }
        if role == .destructive {
            Button(action: action) { confirmLabel }
                .buttonStyle(.tlDestructive)
                .modifier(OptionalIdentifier(id: confirmIdentifier))
        } else {
            Button(action: action) { confirmLabel }
                .buttonStyle(.tlPrimary)
                .modifier(OptionalIdentifier(id: confirmIdentifier))
        }
    }
}

private struct OptionalIdentifier: ViewModifier {
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
