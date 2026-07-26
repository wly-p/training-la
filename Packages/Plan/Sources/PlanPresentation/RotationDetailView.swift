import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

/// 循環編輯頁的導航路由。用 value-based `NavigationLink(value:)` ＋ 祖層 `navigationDestination(for:)`
/// 推入，避免 inline closure 目的地被重評估造成 editor 的 async load 競態（見動作庫 drill-in 陷阱）。
public struct RotationEditRoute: Hashable {
    public let id: UUID
    public init(id: UUID) { self.id = id }
}

/// 循環詳情頁（設計稿 8a）：狀態卡（輪數／已完成次數／範本 capsule）＋組成清單＋管理群組。
/// 不自帶 NavigationStack：由動作庫 tab 共用的 stack push 進來。編輯內容走上方「編輯」→ RotationEditorView。
public struct RotationDetailView: View {
    @Bindable private var viewModel: RotationDetailViewModel
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var showDeactivateConfirm = false
    @State private var showDeleteConfirm = false

    public init(viewModel: RotationDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TLSpace.section) {
                if let rotation = viewModel.rotation {
                    header(rotation)
                    statusCard(rotation)
                    composition(rotation)
                    manage(rotation)
                }
            }
            .padding(.horizontal, TLSpace.page)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TLColor.bg)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        // onAppear（非 .task）：從編輯頁 pop 回來也要重新讀，撈到改名/被刪除。
        .onAppear { Task { await viewModel.load() } }
        .onChange(of: viewModel.didDelete) { _, deleted in if deleted { dismiss() } }
        .tlConfirmationDialog(
            isPresented: $showDeactivateConfirm,
            title: localText("rotation.deactivate.confirm.title"),
            message: localText("rotation.deactivate.confirm.message"),
            confirmLabel: localText("rotation.manage.deactivate"),
            cancelLabel: localText("plan.cancel"),
            role: .normal,
            confirmIdentifier: "confirmDeactivateRotation",
            onConfirm: { Task { await viewModel.deactivate() } }
        )
        .tlConfirmationDialog(
            isPresented: $showDeleteConfirm,
            title: localText("rotation.delete.confirm.title"),
            message: localText("rotation.delete.confirm.message"),
            confirmLabel: localText("plan.delete"),
            cancelLabel: localText("plan.cancel"),
            role: .destructive,
            confirmIdentifier: "confirmDeleteRotation",
            onConfirm: { Task { await viewModel.delete() } }
        )
    }

    // MARK: - 標題列（返回＋編輯）＋ kicker＋名稱

    private func header(_ rotation: Rotation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CircleIconButton(systemImage: "chevron.left", filled: false) { dismiss() }
                    .accessibilityLabel(localText("plan.back"))
                Spacer()
                NavigationLink(value: RotationEditRoute(id: rotation.id)) {
                    localText("plan.edit.short")
                }
                .buttonStyle(.tlText)
            }
            .padding(.top, 12)

            (rotation.isActive ? localText("rotation.detail.kicker.active") : localText("rotation.detail.kicker.inactive"))
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(rotation.isActive ? TLColor.accent600 : TLColor.neutral500)
            Text(verbatim: rotation.name)
                .font(TLFont.zh(TLFont.pageTitle, .bold))
                .tracking(TLFont.pageTitle * -0.02)
                .foregroundStyle(TLColor.text)
                .lineLimit(2)
        }
    }

    // MARK: - 狀態卡

    private func statusCard(_ rotation: Rotation) -> some View {
        VStack(alignment: .leading, spacing: TLSpace.gapM) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "\(rotation.roundsCompleted)")
                    .font(TLFont.display(30))
                    .foregroundStyle(TLColor.text)
                localText("rotation.rounds \(rotation.roundsCompleted)")
                    .font(TLFont.zh(TLFont.rowTitle))
                    .foregroundStyle(TLColor.neutral700)
                Text(verbatim: "·")
                    .foregroundStyle(TLColor.neutral500)
                localText("rotation.detail.completed \(rotation.completedCount)")
                    .font(TLFont.zh(TLFont.rowSub))
                    .foregroundStyle(TLColor.neutral600)
            }
            if !rotation.workouts.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(Array(rotation.workouts.enumerated()), id: \.offset) { index, spec in
                        templateCapsule(spec.name, isCurrent: index == rotation.cursor)
                    }
                }
            }
        }
        .padding(TLSpace.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TLColor.neutral300)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }

    private func templateCapsule(_ name: String, isCurrent: Bool) -> some View {
        Text(verbatim: name)
            .font(TLFont.zh(TLFont.rowSub, .semibold))
            .foregroundStyle(isCurrent ? TLColor.bg : TLColor.neutral700)
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .background(Capsule().fill(isCurrent ? TLColor.accent : TLColor.neutral100))
    }

    // MARK: - 組成清單

    private func composition(_ rotation: Rotation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(localText("rotation.detail.composition \(rotation.workouts.count)"))
            TLGroup {
                ForEach(Array(rotation.workouts.enumerated()), id: \.offset) { index, spec in
                    ListRow(
                        title: Text(verbatim: spec.name),
                        subtitle: Text(PlanFormatting.summary(spec, name: viewModel.name(for:), language: AppLanguage(locale: locale))),
                        leading: { indexBadge(index + 1, isCurrent: index == rotation.cursor) }
                    )
                }
            }
        }
    }

    private func indexBadge(_ n: Int, isCurrent: Bool) -> some View {
        CircleBadge(fill: isCurrent ? TLColor.accent200 : TLColor.neutral200) {
            Text(verbatim: "\(n)")
                .font(TLFont.display(15))
                .foregroundStyle(isCurrent ? TLColor.accent800 : TLColor.neutral700)
        }
    }

    // MARK: - 管理群組

    private func manage(_ rotation: Rotation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(localText("rotation.manage.section"))
            TLGroup {
                ListRow(
                    title: localText("rotation.manage.next"),
                    onTap: { Task { await viewModel.advance() } },
                    trailing: { rightText(Text(verbatim: nextName(rotation))) }
                )
                ListRow(
                    title: localText("rotation.manage.reset"),
                    onTap: { Task { await viewModel.reset() } },
                    trailing: { rightText(localText("rotation.manage.reset.hint")) }
                )
                ListRow(
                    title: localText("rotation.manage.deactivate"),
                    onTap: { showDeactivateConfirm = true },
                    trailing: { rightText(localText("rotation.manage.deactivate.hint")) }
                )
                SettingsRow(
                    localText("rotation.manage.delete"),
                    role: .destructive,
                    onTap: { showDeleteConfirm = true }
                )
            }
            localText("rotation.manage.footer")
                .font(TLFont.zh(TLFont.rowSub, .regular))
                .foregroundStyle(TLColor.neutral500)
                .padding(.horizontal, TLSpace.rowInset)
        }
    }

    private func rightText(_ text: Text) -> some View {
        text
            .font(TLFont.zh(TLFont.rowSub, .regular))
            .foregroundStyle(TLColor.neutral500)
            .multilineTextAlignment(.trailing)
    }

    private func nextName(_ rotation: Rotation) -> String {
        guard !rotation.workouts.isEmpty else { return "" }
        let next = (rotation.cursor + 1) % rotation.workouts.count
        return rotation.workouts[next].name
    }
}
