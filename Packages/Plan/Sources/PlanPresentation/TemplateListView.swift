import PlanDomain
import SharedKernel
import SwiftUI

public struct TemplateListView: View {
    @Bindable private var viewModel: TemplateListViewModel
    @State private var editing: TemplateEditTarget?
    @Environment(\.locale) private var locale

    public init(viewModel: TemplateListViewModel) {
        self.viewModel = viewModel
    }

    // 不自帶 NavigationStack：嵌在動作庫 tab 共用的 NavigationStack 內。
    public var body: some View {
        List {
            ForEach(viewModel.templates) { row($0) }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = .create
                } label: {
                    Label { localText("template.new") } icon: { Image(systemName: "plus") }
                }
            }
        }
        .overlay {
            if viewModel.templates.isEmpty {
                ContentUnavailableView {
                    Label { localText("template.empty") } icon: { Image(systemName: "square.stack.3d.up") }
                } description: {
                    localText("template.empty.hint")
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(item: $editing) { target in
            TemplateFormView(
                target: target.formTarget,
                catalog: viewModel.catalog
            ) { name, drafts in
                switch target {
                case .create:
                    await viewModel.create(name: name, drafts: drafts)
                case .edit(let template):
                    await viewModel.update(id: template.id, name: name, drafts: drafts)
                }
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

    private func row(_ template: WorkoutTemplate) -> some View {
        Button {
            editing = .edit(template)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                // 範本名是使用者輸入的資料（verbatim）
                Text(verbatim: template.name).font(.headline)
                Text(PlanFormatting.templateSummary(template, name: viewModel.name(for:), language: AppLanguage(locale: locale)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.delete(id: template.id) }
            } label: {
                localText("plan.delete")
            }
        }
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
