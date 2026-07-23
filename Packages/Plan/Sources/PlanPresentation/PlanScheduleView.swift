import PlanDomain
import SharedKernel
import SwiftUI

public struct PlanScheduleView: View {
    @Bindable private var viewModel: PlanScheduleViewModel
    @State private var editing: PlanFormTarget?
    @State private var pickingTemplate = false
    @State private var showingRotation = false
    @Environment(\.locale) private var locale
    private let makeRotationEditor: () -> RotationEditorViewModel

    public init(
        viewModel: PlanScheduleViewModel,
        makeRotationEditor: @escaping () -> RotationEditorViewModel
    ) {
        self.viewModel = viewModel
        self.makeRotationEditor = makeRotationEditor
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
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingRotation = true
                    } label: {
                        Label { localText("rotation.title") } icon: { Image(systemName: "arrow.triangle.2.circlepath") }
                    }
                }
                #endif
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
            .sheet(isPresented: $showingRotation, onDismiss: { Task { await viewModel.load() } }) {
                RotationEditorView(viewModel: makeRotationEditor())
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
            Section {
                let items = viewModel.workouts(on: viewModel.selectedDate)
                if items.isEmpty {
                    localText("plan.day.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { row($0) }
                }
            } header: {
                Text(PlanFormatting.dayLabel(viewModel.selectedDate, locale: locale))
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
