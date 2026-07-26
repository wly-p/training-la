import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

/// 動作庫「循環」分頁：切「進行中／未啟用」兩區（設計稿 5c，移除原本綠色 toggle）。
/// 進行中容器加 accent 描邊、右側狀態膠囊；未啟用列右側「啟用」文字動作。
/// 不自帶 NavigationStack：由動作庫 tab 共用的 NavigationStack 承載（見 App/RootView 的 LibraryTabView）。
public struct RotationListView: View {
    @Bindable private var viewModel: RotationListViewModel
    private let makeEditor: @MainActor (UUID) -> RotationEditorViewModel
    private let makeDetail: @MainActor (UUID) -> RotationDetailViewModel
    private let createToken: Int
    @Environment(\.locale) private var locale
    @State private var creating = false
    @State private var renaming: Rotation?

    public init(
        viewModel: RotationListViewModel,
        makeEditor: @escaping @MainActor (UUID) -> RotationEditorViewModel,
        makeDetail: @escaping @MainActor (UUID) -> RotationDetailViewModel,
        createToken: Int = 0
    ) {
        self.viewModel = viewModel
        self.makeEditor = makeEditor
        self.makeDetail = makeDetail
        self.createToken = createToken
    }

    private var active: [Rotation] { viewModel.rotations.filter(\.isActive) }
    private var inactive: [Rotation] { viewModel.rotations.filter { !$0.isActive } }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TLSpace.section) {
                if viewModel.rotations.isEmpty {
                    emptyState
                }
                if !active.isEmpty {
                    section(
                        header: localText("rotation.active.section") + Text(verbatim: " · \(active.count)"),
                        tint: TLColor.accent600,
                        bordered: true
                    ) {
                        ForEach(active) { activeRow($0) }
                    }
                }
                if !inactive.isEmpty {
                    section(
                        header: localText("rotation.inactive.section") + Text(verbatim: " · \(inactive.count)"),
                        tint: TLColor.neutral500,
                        bordered: false
                    ) {
                        ForEach(inactive) { inactiveRow($0) }
                    }
                }
            }
            .padding(.horizontal, TLSpace.page)
            .padding(.top, TLSpace.gapS)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TLColor.bg)
        .navigationDestination(for: UUID.self) { id in
            // active 列 drill-in → 詳情頁（8a）。
            RotationDetailView(viewModel: makeDetail(id))
        }
        .navigationDestination(for: RotationEditRoute.self) { route in
            // 詳情頁「編輯」→ 編輯器。value-based＋祖層 destination，避免 factory VM 競態（drill-in 陷阱）。
            RotationEditorView(viewModel: makeEditor(route.id))
        }
        .task { await viewModel.load() }
        .onChange(of: createToken) { creating = true }
        .sheet(isPresented: $creating) {
            RotationNameFormView(titleKey: "rotation.list.new") { name in
                await viewModel.create(name: name)
            }
        }
        .sheet(item: $renaming) { rotation in
            RotationNameFormView(titleKey: "rotation.rename", name: rotation.name) { name in
                await viewModel.rename(id: rotation.id, name: name)
            }
        }
        .alert(
            localText("plan.error"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button(role: .cancel) {} label: { localText("plan.ok") }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - 區塊

    @ViewBuilder
    private func section<Content: View>(
        header: Text,
        tint: Color,
        bordered: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(header, tint: tint)
            TLGroup(content: content)
                .overlay {
                    if bordered {
                        RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous)
                            .strokeBorder(TLColor.accent300, lineWidth: 1.5)
                    }
                }
        }
    }

    // MARK: - 列

    private func activeRow(_ rotation: Rotation) -> some View {
        // drill-in 用 value-based NavigationLink（＋上面的 navigationDestination(for:)），
        // 與改版前一致；狀態膠囊是純文字、不搶點擊。
        NavigationLink(value: rotation.id) {
            ListRow(
                title: Text(verbatim: rotation.name),
                subtitle: Text(PlanFormatting.rotationSummary(rotation, language: AppLanguage(locale: locale))),
                showChevron: true,
                leading: {
                    CircleBadge(icon: "arrow.triangle.2.circlepath", fill: TLColor.accent, tint: TLColor.bg)
                },
                trailing: { statusPill(rotation) }
            )
        }
        .buttonStyle(.plain)
        .contextMenu { rowMenu(rotation) }
    }

    private func inactiveRow(_ rotation: Rotation) -> some View {
        // 未啟用列：設計稿無 chevron、不 drill-in（低頻編輯先啟用再進）；右側 inline「啟用」。
        // 有進度者副標顯示「停在第 N 輪 · 目前範本」（8b）；沒進度就顯示組成摘要。
        ListRow(
            title: Text(verbatim: rotation.name),
            subtitle: inactiveSubtitle(rotation),
            leading: {
                CircleBadge(icon: "arrow.triangle.2.circlepath", fill: TLColor.neutral300, tint: TLColor.neutral600)
            },
            trailing: {
                Button {
                    Task { await viewModel.setActive(id: rotation.id, true) }
                } label: {
                    localText("plan.activate")
                }
                .buttonStyle(.tlText)
            }
        )
        .contextMenu { rowMenu(rotation) }
    }

    private func inactiveSubtitle(_ rotation: Rotation) -> Text {
        if rotation.completedCount > 0, let current = rotation.current {
            return localText("rotation.pausedAt \(rotation.roundsCompleted)")
                + Text(verbatim: " · \(current.name)")
        }
        return Text(PlanFormatting.rotationSummary(rotation, language: AppLanguage(locale: locale)))
    }

    /// 右側狀態膠囊「7 輪 · 推日」：真實累計輪數（roundsCompleted）＋當前 workout 名。
    @ViewBuilder
    private func statusPill(_ rotation: Rotation) -> some View {
        if let current = rotation.current {
            HStack(spacing: 4) {
                localText("rotation.rounds \(rotation.roundsCompleted)")
                Text(verbatim: "·")
                Text(verbatim: current.name)
            }
            .font(TLFont.zh(TLFont.rowSub, .semibold))
            .foregroundStyle(TLColor.accent700)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(TLColor.accent100))
        }
    }

    @ViewBuilder
    private func rowMenu(_ rotation: Rotation) -> some View {
        Button {
            renaming = rotation
        } label: {
            Label { localText("rotation.rename") } icon: { Image(systemName: "pencil") }
        }
        // 停用改用 contextMenu（DesignSystem 容器非原生 List，無左滑）；主要停用流程在詳情頁。
        if rotation.isActive {
            Button {
                Task { await viewModel.setActive(id: rotation.id, false) }
            } label: {
                Label { localText("rotation.manage.deactivate") } icon: { Image(systemName: "pause") }
            }
        }
        Button(role: .destructive) {
            Task { await viewModel.delete(id: rotation.id) }
        } label: {
            Label { localText("plan.delete") } icon: { Image(systemName: "trash") }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            localText("rotation.empty")
                .font(TLFont.zh(16, .bold))
                .foregroundStyle(TLColor.text)
            localText("rotation.empty.hint")
                .font(TLFont.zh(12.5, .regular))
                .foregroundStyle(TLColor.neutral600)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
