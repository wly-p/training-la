import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

public struct TemplateListView: View {
    @Bindable private var viewModel: TemplateListViewModel
    @State private var editing: TemplateEditTarget?
    /// 14a：剛複製進來的來源範本名，只在那一次 `.sheet` 開著時有值。
    @State private var duplicatedFromName: String?
    @Environment(\.locale) private var locale
    /// 由動作庫殼頁首「+」轉發：值一變就開建立表單。
    private let createToken: Int

    public init(viewModel: TemplateListViewModel, createToken: Int = 0) {
        self.viewModel = viewModel
        self.createToken = createToken
    }

    // 不自帶 NavigationStack：嵌在動作庫 tab 共用的 NavigationStack 內。
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TLSpace.section) {
                if viewModel.templates.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader(localText("template.sectionTitle")
                            + Text(verbatim: " · \(viewModel.templates.count)"))
                        TLGroup {
                            ForEach(viewModel.templates) { row($0) }
                        }
                    }
                }
                explainerCard(localText("template.explainer"))
            }
            .padding(.horizontal, TLSpace.page)
            .padding(.top, TLSpace.gapS)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TLColor.bg)
        .task { await viewModel.load() }
        .onChange(of: createToken) { duplicatedFromName = nil; editing = .create }
        .sheet(item: $editing) { target in
            TemplateFormView(
                target: target.formTarget,
                catalog: viewModel.catalog,
                weightStep: viewModel.weightStep,
                recentExerciseIds: recentExerciseIds,
                duplicatedFromName: duplicatedFromName,
                onSubmit: { name, sets in
                    switch target {
                    case .create:
                        await viewModel.create(name: name, sets: sets)
                    case .edit(let template):
                        await viewModel.update(id: template.id, name: name, sets: sets)
                    }
                },
                onDelete: {
                    if case .edit(let template) = target {
                        await viewModel.delete(id: template.id)
                    }
                }
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

    /// 「最近用過」的動作（picker 用）：跨所有範本，依範本 `updatedAt` 新到舊取不重複的動作 id，取前 5。
    private var recentExerciseIds: [UUID] {
        var seen: Set<UUID> = []
        var result: [UUID] = []
        for template in viewModel.templates.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            for block in template.blocks where !seen.contains(block.exerciseId) {
                seen.insert(block.exerciseId)
                result.append(block.exerciseId)
                if result.count >= 5 { return result }
            }
        }
        return result
    }

    private func row(_ template: WorkoutTemplate) -> some View {
        // 左滑露出「複製」（14a，88pt、neutral-400 底）——左滑只有複製，刪除依 8b 原則不放滑動裡。
        SwipeToRevealRow(
            actionLabel: localText("template.duplicate"),
            actionSystemImage: "doc.on.doc",
            onAction: {
                Task {
                    guard let copy = await viewModel.duplicate(
                        id: template.id,
                        nameSuffix: localString("template.copySuffix", locale)
                    ) else { return }
                    duplicatedFromName = template.name
                    editing = .edit(copy)
                }
            }
        ) {
            ListRow(
                title: Text(verbatim: template.name),
                subtitle: Text(PlanFormatting.templateSummary(template, name: viewModel.name(for:), language: AppLanguage(locale: locale))),
                showChevron: true,
                onTap: {
                    duplicatedFromName = nil
                    editing = .edit(template)
                },
                leading: {
                    // 數字圓章＝含幾個動作（neutral 底，設計稿 5b）。
                    CircleBadge(fill: TLColor.neutral300) {
                        Text(verbatim: "\(template.blocks.count)")
                            .font(TLFont.display(16))
                            .foregroundStyle(TLColor.neutral800)
                    }
                }
            )
            .contextMenu {
                Button(role: .destructive) {
                    Task { await viewModel.delete(id: template.id) }
                } label: {
                    Label { localText("plan.delete") } icon: { Image(systemName: "trash") }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            localText("template.empty")
                .font(TLFont.zh(16, .bold))
                .foregroundStyle(TLColor.text)
            localText("template.empty.hint")
                .font(TLFont.zh(12.5, .regular))
                .foregroundStyle(TLColor.neutral600)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
}

enum TemplateEditTarget: Identifiable {
    case create
    case edit(WorkoutTemplate)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let template): template.id.uuidString
        }
    }

    var formTarget: TemplateFormView.Target {
        switch self {
        case .create: .create
        case .edit(let template): .edit(template)
        }
    }
}
