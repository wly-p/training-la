import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

/// 長期編輯頁的導航路由（見 RotationEditRoute 說明：避免 inline closure 目的地競態）。
public struct ProgramEditRoute: Hashable {
    public let id: UUID
    public init(id: UUID) { self.id = id }
}

/// 長期詳情頁（設計稿 8a 長期變體）：進度卡（day/週期天數/今天＋進度條）＋每天安排清單＋管理群組
/// （重設進度＝回 D1／停用＝刪 assignment／刪除計畫）。編輯走上方「編輯」→ ProgramEditorView。
public struct ProgramDetailView: View {
    @Bindable private var viewModel: ProgramDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeactivateConfirm = false
    @State private var showDeleteConfirm = false

    public init(viewModel: ProgramDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TLSpace.section) {
                if let program = viewModel.program {
                    header(program)
                    if let progress = viewModel.progress {
                        progressCard(progress)
                    }
                    schedule(program)
                    manage
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
        // onAppear（非 .task）：從編輯頁 pop 回來也要重新讀，撈到改名/改週期/被刪除。
        .onAppear { Task { await viewModel.load() } }
        .onChange(of: viewModel.didDelete) { _, deleted in if deleted { dismiss() } }
        .tlConfirmationDialog(
            isPresented: $showDeactivateConfirm,
            title: localText("program.deactivate.confirm.title"),
            message: localText("program.deactivate.confirm.message"),
            confirmLabel: localText("program.manage.deactivate"),
            cancelLabel: localText("plan.cancel"),
            role: .normal,
            confirmIdentifier: "confirmDeactivateProgram",
            onConfirm: { Task { await viewModel.deactivate() } }
        )
        .tlConfirmationDialog(
            isPresented: $showDeleteConfirm,
            title: localText("program.delete.confirm.title"),
            message: localText("program.delete.confirm.message"),
            confirmLabel: localText("plan.delete"),
            cancelLabel: localText("plan.cancel"),
            role: .destructive,
            confirmIdentifier: "confirmDeleteProgram",
            onConfirm: { Task { await viewModel.delete() } }
        )
    }

    private func header(_ program: Program) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CircleIconButton(systemImage: "chevron.left", filled: false) { dismiss() }
                    .accessibilityLabel(localText("plan.back"))
                Spacer()
                NavigationLink(value: ProgramEditRoute(id: program.id)) {
                    localText("plan.edit.short")
                }
                .buttonStyle(.tlText)
            }
            .padding(.top, 12)

            (viewModel.isActive ? localText("program.detail.kicker.active") : localText("program.detail.kicker.inactive"))
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(viewModel.isActive ? TLColor.accent600 : TLColor.neutral500)
            Text(verbatim: program.name)
                .font(TLFont.zh(TLFont.pageTitle, .bold))
                .tracking(TLFont.pageTitle * -0.02)
                .foregroundStyle(TLColor.text)
                .lineLimit(2)
        }
    }

    private func progressCard(_ progress: ProgramProgress) -> some View {
        VStack(spacing: TLSpace.gapM) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: "\(progress.day)")
                        .font(TLFont.display(30))
                        .foregroundStyle(TLColor.text)
                    (Text(verbatim: "/ \(progress.totalDays) ") + localText("program.dayUnit"))
                        .font(TLFont.zh(TLFont.rowSub))
                        .foregroundStyle(TLColor.neutral500)
                }
                Spacer()
                (localText("program.today") + Text(verbatim: "：\(progress.todayWorkoutName ?? "—")"))
                    .font(TLFont.zh(TLFont.rowSub, .semibold))
                    .foregroundStyle(TLColor.neutral700)
            }
            progressBar(Double(progress.day) / Double(max(1, progress.totalDays)))
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.neutral300)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }

    private func progressBar(_ ratio: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(TLColor.neutral100)
                Capsule().fill(TLColor.accent)
                    .frame(width: geo.size.width * min(1, max(0, ratio)))
            }
        }
        .frame(height: 6)
    }

    private func schedule(_ program: Program) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(localText("program.schedule.section"))
            TLGroup {
                ForEach(0..<program.cycleLength, id: \.self) { dayIndex in
                    let spec = program.workout(dayIndex: dayIndex)
                    ListRow(
                        title: spec.map { Text(verbatim: $0.name) } ?? localText("program.day.rest"),
                        leading: { indexBadge(dayIndex + 1, rest: spec == nil) }
                    )
                }
            }
        }
    }

    private func indexBadge(_ n: Int, rest: Bool) -> some View {
        CircleBadge(fill: rest ? TLColor.neutral200 : TLColor.accent200) {
            Text(verbatim: "\(n)")
                .font(TLFont.display(15))
                .foregroundStyle(rest ? TLColor.neutral500 : TLColor.accent800)
        }
    }

    private var manage: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(localText("rotation.manage.section"))
            TLGroup {
                if viewModel.isActive {
                    ListRow(
                        title: localText("program.manage.resetProgress"),
                        onTap: { Task { await viewModel.resetProgressToStart() } },
                        trailing: { rightText(localText("program.manage.resetProgress.hint")) }
                    )
                    ListRow(
                        title: localText("program.manage.deactivate"),
                        onTap: { showDeactivateConfirm = true },
                        trailing: { rightText(localText("program.manage.deactivate.hint")) }
                    )
                }
                SettingsRow(
                    localText("program.manage.delete"),
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
    }
}
