import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

/// 動作庫「長期」分頁：進行中的升級成進度卡（設計稿 5d），未啟用為一般列。
///
/// ⚠️ 佔位：長期課表的「進行中／進度／今天」需要 ProgramAssignment（在課表 tab 那條線），
/// ProgramListViewModel 目前拿不到。這裡把第一筆當「進行中」、天數/進度/今天用**假資料**呈現，
/// 「啟用」為 no-op。全部標 TODO，之後接上 assignment/進度資料再改真。
public struct ProgramListView: View {
    @Bindable private var viewModel: ProgramListViewModel
    private let makeEditor: @MainActor (UUID) -> ProgramEditorViewModel
    private let createToken: Int
    @Environment(\.locale) private var locale
    @State private var creating = false

    public init(
        viewModel: ProgramListViewModel,
        makeEditor: @escaping @MainActor (UUID) -> ProgramEditorViewModel,
        createToken: Int = 0
    ) {
        self.viewModel = viewModel
        self.makeEditor = makeEditor
        self.createToken = createToken
    }

    // TODO 假資料：無 assignment/啟用狀態，暫定「第一筆＝進行中，其餘＝未啟用」。
    private var activeProgram: Program? { viewModel.programs.first }
    private var inactivePrograms: [Program] { Array(viewModel.programs.dropFirst()) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TLSpace.section) {
                if viewModel.programs.isEmpty {
                    emptyState
                }
                if let activeProgram {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(localText("rotation.active.section") + Text(verbatim: " · 1"), tint: TLColor.accent600)
                        activeCard(activeProgram)
                    }
                }
                if !inactivePrograms.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(localText("rotation.inactive.section") + Text(verbatim: " · \(inactivePrograms.count)"), tint: TLColor.neutral500)
                        TLGroup {
                            ForEach(inactivePrograms) { inactiveRow($0) }
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
        .task { await viewModel.load() }
        .onChange(of: createToken) { creating = true }
        .sheet(isPresented: $creating) {
            ProgramCreateFormView { name, cycleLength in
                await viewModel.create(name: name, cycleLength: cycleLength)
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

    // MARK: - 進行中卡片（佔位進度）

    private func activeCard(_ program: Program) -> some View {
        // TODO 假資料：以週期一半當「目前天數」、據此算進度；「今天」取第一個有課的 workout 名。
        let total = program.cycleLength
        let fakeDay = max(1, total / 2)
        let progress = Double(fakeDay) / Double(max(1, total))
        let todayName = program.days.min(by: { $0.key < $1.key })?.value.name

        return VStack(spacing: TLSpace.gapM) {
            // 上半：可點進編輯（inline destination NavigationLink，與改版前一致）
            NavigationLink {
                ProgramEditorView(viewModel: makeEditor(program.id))
            } label: {
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

            // 下半：天數＋今天＋進度條
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: "\(fakeDay)")
                        .font(TLFont.display(26))
                        .foregroundStyle(TLColor.text)
                    (Text(verbatim: "/ \(total) ") + localText("program.dayUnit"))
                        .font(TLFont.zh(TLFont.rowSub))
                        .foregroundStyle(TLColor.neutral500)
                }
                Spacer()
                (localText("program.today") + Text(verbatim: "：\(todayName ?? "—")"))
                    .font(TLFont.zh(TLFont.rowSub, .semibold))
                    .foregroundStyle(TLColor.neutral700)
            }
            progressBar(progress)
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous)
                .strokeBorder(TLColor.accent300, lineWidth: 1.5)
        }
    }

    private func progressBar(_ progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(TLColor.neutral200)
                Capsule().fill(TLColor.accent)
                    .frame(width: geo.size.width * min(1, max(0, progress)))
            }
        }
        .frame(height: 6)
    }

    // MARK: - 未啟用列

    private func inactiveRow(_ program: Program) -> some View {
        ListRow(
            title: Text(verbatim: program.name),
            subtitle: Text(PlanFormatting.programLibrarySummary(program, language: AppLanguage(locale: locale))),
            leading: {
                CircleBadge(icon: "chart.bar", fill: TLColor.neutral300, tint: TLColor.neutral600)
            },
            trailing: {
                Button {
                    // TODO 假資料：啟用長期課表＝建立 ProgramAssignment（選起始日/模式），
                    // 需要課表 tab 那條線的資料；此處先 no-op。
                } label: {
                    localText("plan.activate")
                }
                .buttonStyle(.tlText)
            }
        )
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

/// 建立長期課表：名稱 + 週期天數。
private struct ProgramCreateFormView: View {
    let onSubmit: (String, Int) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var cycleLength = 7

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("", text: $name, prompt: localText("program.name.placeholder"))
                }
                Section {
                    Stepper(value: $cycleLength, in: 1...60) {
                        HStack {
                            localText("program.cycleLength")
                            Spacer()
                            Text(verbatim: "\(cycleLength)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    localText("program.cycleLength.hint")
                }
            }
            .navigationTitle(localText("program.list.new"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("plan.cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await onSubmit(name, cycleLength); dismiss() }
                    } label: {
                        localText("plan.save")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
