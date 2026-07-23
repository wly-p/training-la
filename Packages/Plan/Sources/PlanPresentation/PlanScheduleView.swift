import PlanDomain
import SharedKernel
import SwiftUI

public struct PlanScheduleView: View {
    @Bindable private var viewModel: PlanScheduleViewModel
    @State private var editing: PlanFormTarget?
    @Environment(\.locale) private var locale

    public init(viewModel: PlanScheduleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.datedWorkouts) { row($0) }
            }
            .navigationTitle(localText("plan.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = .create
                    } label: {
                        Label { localText("plan.new") } icon: { Image(systemName: "plus") }
                    }
                }
            }
            .overlay {
                if viewModel.planWorkouts.isEmpty {
                    ContentUnavailableView {
                        Label { localText("plan.empty") } icon: { Image(systemName: "calendar") }
                    } description: {
                        localText("plan.empty.hint")
                    }
                }
            }
            .task { await viewModel.load() }
            .sheet(item: $editing) { target in
                PlanWorkoutFormView(
                    target: target,
                    catalog: viewModel.catalog,
                    readOnly: target.isDone
                ) { name, date, drafts in
                    switch target {
                    case .create:
                        await viewModel.create(name: name, date: date, drafts: drafts)
                    case .edit(let plan):
                        await viewModel.update(id: plan.id, name: name, date: date, drafts: drafts)
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
    }

    private func row(_ plan: PlanWorkout) -> some View {
        Button {
            editing = .edit(plan)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // 課表名是 DB 資料（verbatim）；沒命名時用本地化的「未命名」
                    (plan.name.map { Text(verbatim: $0) } ?? localText("plan.untitled")).font(.headline)
                    Spacer()
                    Text(PlanFormatting.dayLabel(plan.date, locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if plan.status == .done {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                Text(PlanFormatting.summary(plan, name: viewModel.name(for:), language: AppLanguage(locale: locale)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.delete(id: plan.id) }
            } label: {
                localText("plan.delete")
            }
        }
    }
}

enum PlanFormTarget: Identifiable {
    case create
    case edit(PlanWorkout)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let plan): plan.id.uuidString
        }
    }

    /// 已完成的排課 → 表單以唯讀開啟。
    var isDone: Bool {
        if case .edit(let plan) = self { return plan.status == .done }
        return false
    }
}
