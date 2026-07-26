import SwiftUI

/// 新增／編輯頁共用骨架（設計稿 9a/9b/9c）。
/// - 頂列：左「取消」／右「儲存」（`accent-700`，`canSave == false` 時降 `neutral-400` 並停用）。**不用返回箭頭**。
/// - 主標＝可直接編輯的名稱欄位（34pt），下方一條 1px `neutral-300`；可選英文副標（顯示用）。
/// - 內容為呼叫端塞的群組（用 `TLGroup`）；底部「刪除」群組也由呼叫端放進 content（僅編輯模式）。
///
/// 文字（取消/儲存/prompt）吃 `Text`，由呼叫端用 `localText` 建。
public struct EditScaffold<Content: View>: View {
    @Binding private var title: String
    private let titlePrompt: Text
    private let subtitle: Text?
    private let canSave: Bool
    private let cancelLabel: Text
    private let saveLabel: Text
    private let onCancel: () -> Void
    private let onSave: () -> Void
    private let content: Content

    @FocusState private var titleFocused: Bool

    public init(
        title: Binding<String>,
        titlePrompt: Text,
        subtitle: Text? = nil,
        canSave: Bool,
        cancelLabel: Text,
        saveLabel: Text,
        onCancel: @escaping () -> Void,
        onSave: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self._title = title
        self.titlePrompt = titlePrompt
        self.subtitle = subtitle
        self.canSave = canSave
        self.cancelLabel = cancelLabel
        self.saveLabel = saveLabel
        self.onCancel = onCancel
        self.onSave = onSave
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: TLSpace.section) {
                    titleField
                    content
                }
                .padding(.horizontal, TLSpace.page)
                .padding(.top, TLSpace.gapL)
                .padding(.bottom, 40)
                // 點內容區的空白處收鍵盤（列/按鈕自己的 tap 手勢優先，不會被這個蓋掉）。
                .contentShape(Rectangle())
                .onTapGesture { titleFocused = false }
            }
            // 一開始拖曳就收鍵盤：名稱欄位／備註等文字輸入沒有「完成」鍵時，鍵盤才收得起來。
            // `.interactively`（跟手漸進收合）在 UITest 的合成 swipe 上不可靠，用 `.immediately`。
            .scrollDismissesKeyboard(.immediately)
        }
        .background(TLColor.bg.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                cancelLabel
                    .font(TLFont.zh(15.5, .medium))
                    .foregroundStyle(TLColor.neutral600)
            }
            Spacer()
            Button(action: onSave) {
                saveLabel
                    .font(TLFont.zh(15.5, .bold))
                    .foregroundStyle(canSave ? TLColor.accent700 : TLColor.neutral400)
            }
            .disabled(!canSave)
            .accessibilityIdentifier("editScaffoldSave")
        }
        .padding(.horizontal, TLSpace.page)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("", text: $title, prompt: titlePrompt.foregroundColor(TLColor.neutral400))
                .font(TLFont.zh(TLFont.pageTitle, .bold))
                .tracking(TLFont.pageTitle * -0.02)
                .foregroundStyle(TLColor.text)
                .focused($titleFocused)
                .accessibilityIdentifier("editScaffoldTitle")
            if let subtitle {
                subtitle
                    .font(TLFont.zh(13, .regular))
                    .foregroundStyle(TLColor.neutral600)
            }
            Rectangle()
                .fill(TLColor.neutral300)
                .frame(height: 1)
                .padding(.top, 6)
        }
    }
}

/// 編輯頁的群組區塊：kicker 標題（可選）＋群組容器；下方可帶一行說明（`neutral-500`）。
/// 用來組 9a/9b/9c 的每一段（肌群／器材／備註／被使用於…）。
public struct EditSection<Content: View>: View {
    private let header: Text?
    private let footer: Text?
    private let content: Content

    public init(_ header: Text? = nil, footer: Text? = nil, @ViewBuilder content: () -> Content) {
        self.header = header
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let header {
                SectionHeader(header)
                    .padding(.bottom, -2)
            }
            content
            if let footer {
                footer
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral500)
                    .padding(.horizontal, TLSpace.rowInset)
            }
        }
    }
}
