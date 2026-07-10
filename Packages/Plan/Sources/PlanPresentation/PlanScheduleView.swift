import PlanDomain
import SharedKernel
import SwiftUI

public struct PlanScheduleView: View {
    @Bindable private var viewModel: PlanScheduleViewModel
    @State private var editing: PlanFormTarget?

    public init(viewModel: PlanScheduleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                if !viewModel.datedWorkouts.isEmpty {
                    Section("指定日期") {
                        ForEach(viewModel.datedWorkouts) { row($0) }
                    }
                }
                if !viewModel.cycleWorkouts.isEmpty {
                    Section("循環課表") {
                        ForEach(viewModel.cycleWorkouts) { row($0) }
                    }
                }
            }
            .navigationTitle("課表")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = .create
                    } label: {
                        Label("新增排課", systemImage: "plus")
                    }
                }
            }
            .overlay {
                if viewModel.planWorkouts.isEmpty {
                    ContentUnavailableView(
                        "還沒有排課",
                        systemImage: "calendar",
                        description: Text("排課只是預填來源，不排課也能直接記錄訓練")
                    )
                }
            }
            .task { await viewModel.load() }
            .sheet(item: $editing) { target in
                PlanWorkoutFormView(
                    target: target,
                    catalog: viewModel.catalog
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
                "出錯了",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.dismissError() } }
                )
            ) {
                Button("好", role: .cancel) {}
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
                    Text(plan.name ?? "未命名").font(.headline)
                    Spacer()
                    if let date = plan.date {
                        Text(PlanFormatting.dayLabel(date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if plan.status == .done {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                Text(PlanFormatting.summary(plan, name: viewModel.name(for:)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button("刪除", role: .destructive) {
                Task { await viewModel.delete(id: plan.id) }
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
}
