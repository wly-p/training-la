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

    /// 長期課表目前是**未完成**的功能（體檢 P0-2）：套用之後訓練分頁看不到今天的課表，
    /// 必須每個訓練日手動回課表分頁按「加入這天」。病因是進度由日期算出來而不是由訓練算出來，
    /// 解法已定稿但刻意暫緩（見 dev-notes/program-model-design.local.md）。
    ///
    /// 在重做完成前先把話講明白——留著入口讓已經建好課表的人還進得去，
    /// 但不要讓任何人以為這是完成品。
    private var experimentalNotice: some View {
        TLCard(radius: .inner, fill: TLColor.accent200) {
            HStack(alignment: .top, spacing: TLSpace.gapS) {
                Image(systemName: "flask")
                    .font(.system(size: TLIcon.inline, weight: .semibold))
                    .foregroundStyle(TLColor.accent700)
                VStack(alignment: .leading, spacing: TLSpace.titleSubGap) {
                    localText("program.experimental.title")
                        .font(TLFont.zh(TLFont.rowTitle, .semibold))
                        .foregroundStyle(TLColor.accent800)
                    localText("program.experimental.message")
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.accent700)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("program.experimentalNotice")
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TLSpace.section) {
                experimentalNotice
                if viewModel.programs.isEmpty {
                    emptyState
                }
                if !viewModel.activePrograms.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        TLSectionHeader(localText("rotation.active.section") + Text(verbatim: " · \(viewModel.activePrograms.count)"), tint: TLColor.accent600)
                        VStack(spacing: TLSpace.gapM) {
                            ForEach(viewModel.activePrograms) { programRow($0, active: true) }
                        }
                    }
                }
                if !viewModel.inactivePrograms.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        TLSectionHeader(localText("rotation.inactive.section") + Text(verbatim: " · \(viewModel.inactivePrograms.count)"), tint: TLColor.neutral500)
                        TLGroup {
                            ForEach(viewModel.inactivePrograms) { programRow($0, active: false) }
                        }
                    }
                }
                explainerCard(localText("program.explainer"))
            }
            .padding(.horizontal, TLSpace.page)
            .padding(.top, TLSpace.gapS)
            .padding(.bottom, TLSpace.pageBottom)
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
                    weightStep: viewModel.weightStep,
                    name: viewModel.name(for:),
                    onSubmit: { name, cycleLength, days, intensityFactor in
                        await viewModel.update(
                            id: program.id, name: name, cycleLength: cycleLength, days: days,
                            intensityFactor: intensityFactor
                        )
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
                    weightStep: viewModel.weightStep,
                name: viewModel.name(for:),
                onSubmit: { name, cycleLength, days, intensityFactor in
                    await viewModel.create(
                        name: name, cycleLength: cycleLength, days: days, intensityFactor: intensityFactor
                    )
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
            // `?? ""` 會讓那個空字串變成可翻譯字面量，被抽進 String Catalog
            // 變成一個永遠不會被翻譯的空 key（體檢 E11）。改成條件式。
            if let message = viewModel.errorMessage { Text(message) }
        }
    }

    // MARK: - 進行中卡片（真實進度）

    private func programRow(_ program: Program, active: Bool) -> some View {
        let p = viewModel.progressByProgram[program.id]
        return ProgramRow(
            id: program.id,
            name: program.name,
            summary: Text(PlanFormatting.programLibrarySummary(program, language: AppLanguage(locale: locale))),
            progress: active ? p.map {
                ProgramRow.Progress(day: $0.day, totalDays: $0.totalDays, todayWorkoutName: $0.todayWorkoutName)
            } : nil,
            activateButton: active ? nil : AnyView(
                Button {
                    Task { await viewModel.activate(id: program.id) }
                } label: {
                    localText("plan.activate")
                }
                .buttonStyle(.tlText)
            ),
            dayUnit: localText("program.dayUnit"),
            todayLabel: localText("program.today"),
            menu: AnyView(
                Button(role: .destructive) {
                    Task { await viewModel.delete(id: program.id) }
                } label: {
                    Label { localText("plan.delete") } icon: { Image(systemName: "trash") }
                }
            )
        )
    }

    private func explainerCard(_ text: Text) -> some View {
        TLCard(padding: .roomy) {
            text
                .font(TLFont.zh(TLFont.rowTitle, .regular))
                .foregroundStyle(TLColor.neutral600)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var emptyState: some View {
        TLInlineEmptyState(
            title: localText("program.empty"),
            hint: localText("program.empty.hint")
        )
    }
}
