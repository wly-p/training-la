import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

/// 動作庫「長期」分頁：進行中的升級成進度卡（設計稿 5d），未啟用為一般列。
/// 進行中／進度／今天由**真實 assignment**（`viewModel.progressByProgram`）決定；點卡進詳情頁 8a。
public struct ProgramListView: View {
    @Bindable private var viewModel: ProgramListViewModel
    private let makeDetail: @MainActor (UUID) -> ProgramDetailViewModel
    private let createToken: Int
    @Environment(\.locale) private var locale
    @State private var creating = false

    public init(
        viewModel: ProgramListViewModel,
        makeDetail: @escaping @MainActor (UUID) -> ProgramDetailViewModel,
        createToken: Int = 0
    ) {
        self.viewModel = viewModel
        self.makeDetail = makeDetail
        self.createToken = createToken
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TLSpace.section) {
                if viewModel.programs.isEmpty {
                    emptyState
                }
                if !viewModel.activePrograms.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(localText("rotation.active.section") + Text(verbatim: " · \(viewModel.activePrograms.count)"), tint: TLColor.accent600)
                        VStack(spacing: TLSpace.gapM) {
                            ForEach(viewModel.activePrograms) { activeCard($0) }
                        }
                    }
                }
                if !viewModel.inactivePrograms.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(localText("rotation.inactive.section") + Text(verbatim: " · \(viewModel.inactivePrograms.count)"), tint: TLColor.neutral500)
                        TLGroup {
                            ForEach(viewModel.inactivePrograms) { inactiveRow($0) }
                        }
                    }
                }
                explainerCard(localText("program.explainer"))
            }
            .padding(.horizontal, TLSpace.page)
            .padding(.top, TLSpace.gapS)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TLColor.bg)
        .navigationDestination(for: UUID.self) { id in
            ProgramDetailView(viewModel: makeDetail(id))
        }
        .navigationDestination(for: ProgramEditRoute.self) { route in
            // 編輯：直接把清單裡已載入的 Program 物件交給編輯頁，不再依 id 非同步查一次
            // （同 RotationEditorView 的作法，見 memory nav-drill-in-pitfall）。
            if let program = viewModel.programs.first(where: { $0.id == route.id }) {
                ProgramEditorView(
                    target: .edit(program),
                    templates: viewModel.templates,
                    name: viewModel.name(for:),
                    onSubmit: { name, cycleLength, days in
                        await viewModel.update(id: program.id, name: name, cycleLength: cycleLength, days: days)
                    },
                    onDelete: { await viewModel.delete(id: program.id) }
                )
            }
        }
        .task { await viewModel.load() }
        // 從 Detail／Editor 返回也要刷新（那些頁面各自改完資料，這裡的清單快照要跟上）。
        .onAppear { Task { await viewModel.load() } }
        .onChange(of: createToken) { creating = true }
        .sheet(isPresented: $creating) {
            ProgramEditorView(
                target: .create,
                templates: viewModel.templates,
                name: viewModel.name(for:),
                onSubmit: { name, cycleLength, days in
                    await viewModel.create(name: name, cycleLength: cycleLength, days: days)
                },
                onDelete: {}
            )
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

    // MARK: - 進行中卡片（真實進度）

    private func activeCard(_ program: Program) -> some View {
        let progress = viewModel.progressByProgram[program.id]
        return VStack(spacing: TLSpace.gapM) {
            // 上半：點進詳情頁（8a）
            NavigationLink(value: program.id) {
                HStack(spacing: TLSpace.gapM) {
                    CircleBadge(icon: "chart.bar", fill: TLColor.accent, tint: TLColor.bg)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: program.name)
                            .font(TLFont.zh(TLFont.rowTitle))
                            .foregroundStyle(TLColor.text)
                            .lineLimit(1)
                        Text(PlanFormatting.programLibrarySummary(program, language: AppLanguage(locale: locale)))
                            .font(TLFont.zh(TLFont.rowSub, .regular))
                            .foregroundStyle(TLColor.neutral500)
                            .lineLimit(1)
                    }
                    Spacer(minLength: TLSpace.gapS)
                    Chevron()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 下半：天數＋今天＋進度條（真實）
            if let progress {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(verbatim: "\(progress.day)")
                            .font(TLFont.display(26))
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
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous)
                .strokeBorder(TLColor.accent300, lineWidth: 1.5)
        }
    }

    private func progressBar(_ ratio: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(TLColor.neutral200)
                Capsule().fill(TLColor.accent)
                    .frame(width: geo.size.width * min(1, max(0, ratio)))
            }
        }
        .frame(height: 6)
    }

    // MARK: - 未啟用列

    private func inactiveRow(_ program: Program) -> some View {
        // 左側可點進詳情頁（8a，可再進編輯）、右側 inline「啟用」——兩個獨立點擊區。
        HStack(spacing: TLSpace.gapM) {
            NavigationLink(value: program.id) {
                HStack(spacing: TLSpace.gapM) {
                    CircleBadge(icon: "chart.bar", fill: TLColor.neutral300, tint: TLColor.neutral600)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: program.name)
                            .font(TLFont.zh(TLFont.rowTitle))
                            .foregroundStyle(TLColor.text)
                            .lineLimit(1)
                        Text(PlanFormatting.programLibrarySummary(program, language: AppLanguage(locale: locale)))
                            .font(TLFont.zh(TLFont.rowSub, .regular))
                            .foregroundStyle(TLColor.neutral500)
                            .lineLimit(1)
                    }
                    Spacer(minLength: TLSpace.gapS)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                Task { await viewModel.activate(id: program.id) }
            } label: {
                localText("plan.activate")
            }
            .buttonStyle(.tlText)
        }
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: TLSize.rowWithSub)
        .contextMenu {
            Button(role: .destructive) {
                Task { await viewModel.delete(id: program.id) }
            } label: {
                Label { localText("plan.delete") } icon: { Image(systemName: "trash") }
            }
        }
    }

    private func explainerCard(_ text: Text) -> some View {
        text
            .font(TLFont.zh(TLFont.rowTitle, .regular))
            .foregroundStyle(TLColor.neutral600)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, TLSpace.page)
            .padding(.vertical, 26)
            .background(TLColor.neutral100)
            .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            localText("program.empty")
                .font(TLFont.zh(16, .bold))
                .foregroundStyle(TLColor.text)
            localText("program.empty.hint")
                .font(TLFont.zh(12.5, .regular))
                .foregroundStyle(TLColor.neutral600)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
