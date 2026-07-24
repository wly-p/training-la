import PlanDomain
import SharedKernel
import SwiftUI

public struct PlanScheduleView: View {
    @Bindable private var viewModel: PlanScheduleViewModel
    @State private var editing: PlanFormTarget?
    @State private var pickingTemplate = false
    @State private var applyingProgram = false
    @Environment(\.locale) private var locale

    public init(viewModel: PlanScheduleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let wide = geo.size.width > 700
                let layout = wide ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
                layout {
                    MonthCalendarView(
                        selectedDate: $viewModel.selectedDate,
                        markedDates: viewModel.markedDates,
                        mark: viewModel.mark(on:)
                    )
                    // 高度交給 sizeThatFits 依當月週數決定（narrow）；wide 時月曆佔左側固定寬、撐滿高。
                    .frame(maxWidth: wide ? 360 : .infinity, maxHeight: wide ? .infinity : nil)
                    Divider()
                    dayDetail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(localText("plan.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            editing = .create(viewModel.selectedDate)
                        } label: {
                            Label { localText("plan.addBlank") } icon: { Image(systemName: "square.and.pencil") }
                        }
                        Button {
                            pickingTemplate = true
                        } label: {
                            Label { localText("plan.addFromTemplate") } icon: { Image(systemName: "square.stack.3d.up") }
                        }
                        Button {
                            applyingProgram = true
                        } label: {
                            Label { localText("plan.applyProgram") } icon: { Image(systemName: "calendar.badge.clock") }
                        }
                    } label: {
                        Label { localText("plan.new") } icon: { Image(systemName: "plus") }
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
                    if case .edit(let plan) = target {
                        await viewModel.update(id: plan.id, name: name, date: date, drafts: drafts)
                    } else {
                        await viewModel.create(name: name, date: date, drafts: drafts)
                    }
                }
            }
            .sheet(isPresented: $pickingTemplate) {
                TemplatePickerView(templates: viewModel.templates) { template in
                    Task { await viewModel.addFromTemplate(templateId: template.id, on: viewModel.selectedDate) }
                }
            }
            .sheet(isPresented: $applyingProgram) {
                ProgramApplyView(
                    programs: viewModel.programs,
                    assignments: viewModel.assignments,
                    defaultStartDate: viewModel.selectedDate,
                    programName: viewModel.programName(for:),
                    onApply: { programId, startDate, mode in
                        await viewModel.applyProgram(programId: programId, startDate: startDate, mode: mode)
                    },
                    onStop: { assignmentId in
                        await viewModel.stopAssignment(id: assignmentId)
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
    }

    private var dayDetail: some View {
        List {
            let items = viewModel.workouts(on: viewModel.selectedDate)
            let projected = viewModel.projections(on: viewModel.selectedDate)
            Section {
                if items.isEmpty && projected.isEmpty {
                    localText("plan.day.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { row($0) }
                    ForEach(projected) { projectedRow($0) }
                }
            } header: {
                Text(PlanFormatting.dayLabel(viewModel.selectedDate, locale: locale))
            }
        }
    }

    /// 長期課表投影建議（尚未落地）：顯示「排定：X」＋「加入這天」把它變成真實排課。
    private func projectedRow(_ projected: ProjectedWorkout) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label { localText("plan.projected") } icon: { Image(systemName: "calendar.badge.clock") }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                // 課表名是使用者資料（verbatim）
                Text(verbatim: projected.programName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            // workout 名是使用者資料（verbatim）
            Text(verbatim: projected.spec.name).font(.headline)
            Text(PlanFormatting.summary(projected.spec, name: viewModel.name(for:), language: AppLanguage(locale: locale)))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                Task { await viewModel.materialize(projected) }
            } label: {
                Label { localText("plan.addThisDay") } icon: { Image(systemName: "plus.circle") }
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
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

/// 選課表範本加到某天。
private struct TemplatePickerView: View {
    let templates: [WorkoutTemplate]
    let onSelect: (WorkoutTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(templates) { template in
                Button {
                    onSelect(template)
                    dismiss()
                } label: {
                    Text(verbatim: template.name)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(localText("plan.addFromTemplate"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("plan.cancel") }
                }
            }
            .overlay {
                if templates.isEmpty {
                    ContentUnavailableView {
                        Label { localText("template.empty") } icon: { Image(systemName: "square.stack.3d.up") }
                    } description: {
                        localText("template.empty.hint")
                    }
                }
            }
        }
    }
}

enum PlanFormTarget: Identifiable {
    case create(DayDate)
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
