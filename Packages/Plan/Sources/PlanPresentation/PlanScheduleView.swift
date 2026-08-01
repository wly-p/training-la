import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

/// 課表分頁（設計稿 4d）：原生月曆佔了 40% 高度只為顯示幾個標記，換成 `WeekDateStrip`
/// （左右滑動換週）。省下的空間給當天課表內容；整月檢視降級成清單底部的「月檢視」入口
/// （顯示本月已完成次數），不是預設呈現。
public struct PlanScheduleView: View {
    @Bindable private var viewModel: PlanScheduleViewModel
    @State private var editing: PlanFormTarget?
    @State private var pickingTemplate = false
    @State private var applyingProgram = false
    @State private var showingMonthView = false
    @Environment(\.locale) private var locale

    public init(viewModel: PlanScheduleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PageHeader(localText("plan.title"), kicker: monthKicker) {
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
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(TLColor.bg)
                                .frame(width: TLSize.iconButton, height: TLSize.iconButton)
                                .background(TLColor.accent)
                                .clipShape(Capsule())
                        }
                        .accessibilityLabel(localText("plan.new"))
                    }

                    WeekDateStrip(
                        selectedDate: selectedDateBinding,
                        mark: { weekMark(for: DayDate($0)) }
                    )
                    .padding(.top, TLSpace.gapM)
                    localText("plan.weekStrip.hint")
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                        .padding(.horizontal, TLSpace.page)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: TLSpace.section) {
                        daySection
                        monthViewEntryRow
                    }
                    .padding(.horizontal, TLSpace.page)
                    .padding(.top, TLSpace.section)
                }
                .padding(.bottom, 40)
            }
            .background(TLColor.bg.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .task { await viewModel.load() }
            .sheet(isPresented: $showingMonthView) {
                MonthViewSheet(
                    selectedDate: selectedDateBinding,
                    markedDates: Set(viewModel.markedDates.map(\.asDate)),
                    mark: { weekMark(for: DayDate($0)) }
                )
            }
            .sheet(item: $editing) { target in
                PlanWorkoutFormView(
                    target: target,
                    catalog: viewModel.catalog,
                    weightStep: viewModel.weightStep,
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
                PickerSheet(
                    title: localText("plan.addFromTemplate"),
                    searchPrompt: localText("plan.searchTemplates"),
                    allItems: viewModel.templates.map { TemplatePickerItem(template: $0, name: viewModel.name(for:)) },
                    selection: .single { item in
                        Task { await viewModel.addFromTemplate(templateId: item.id, on: viewModel.selectedDate) }
                    },
                    labels: PlanPickerLabels.standard
                )
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

    // MARK: - Week strip 橋接

    /// `WeekDateStrip` 只吃 `Date`；`PlanScheduleViewModel.selectedDate` 是 `DayDate`
    /// （見 SharedKernel：純日曆日，避免時區把日期偏移一天），這裡互轉。
    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.selectedDate.asDate },
            set: { viewModel.selectedDate = DayDate($0) }
        )
    }

    private func weekMark(for date: DayDate) -> WeekDateStrip.DayMark {
        switch viewModel.mark(on: date) {
        case .done: .completed
        case .scheduled, .projected: .scheduled
        case nil: .none
        }
    }

    private var monthKicker: Text {
        Text(verbatim: String(format: "%d 月", viewModel.selectedDate.month))
    }

    // MARK: - 當天課表

    private var daySection: some View {
        let items = viewModel.workouts(on: viewModel.selectedDate)
        let projected = viewModel.projections(on: viewModel.selectedDate)
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(Text(PlanFormatting.dayLabel(viewModel.selectedDate, locale: locale)))
            if items.isEmpty && projected.isEmpty {
                emptyDay
            } else {
                TLGroup {
                    ForEach(items) { row($0) }
                    ForEach(projected) { projectedRow($0) }
                }
            }
        }
    }

    private var emptyDay: some View {
        localText("plan.day.empty")
            .font(TLFont.zh(TLFont.rowSub, .regular))
            .foregroundStyle(TLColor.neutral500)
            .padding(.vertical, 18)
    }

    private func row(_ plan: PlanWorkout) -> some View {
        ListRow(
            title: plan.name.map { Text(verbatim: $0) } ?? localText("plan.untitled"),
            subtitle: Text(PlanFormatting.summary(plan, name: viewModel.name(for:), language: AppLanguage(locale: locale))),
            showChevron: true,
            onTap: { editing = .edit(plan) },
            leading: {
                CircleBadge(fill: plan.status == .done ? TLColor.accent : TLColor.neutral300) {
                    if plan.status == .done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TLColor.bg)
                    } else {
                        Text(verbatim: "\(plan.orderIndex + 1)")
                            .font(TLFont.display(15))
                            .foregroundStyle(TLColor.neutral700)
                    }
                }
            }
        )
        .contextMenu {
            Button(role: .destructive) {
                Task { await viewModel.delete(id: plan.id) }
            } label: {
                Label { localText("plan.delete") } icon: { Image(systemName: "trash") }
            }
        }
    }

    /// 長期課表投影建議（尚未落地）：顯示「排定：X」＋「加入這天」把它變成真實排課。
    /// 「加入這天」是獨立按鈕（不是整列 tap）——這一列本身還不是真的排課，不該點哪裡都觸發落地。
    private func projectedRow(_ projected: ProjectedWorkout) -> some View {
        ListRow(
            title: Text(verbatim: projected.spec.name),
            subtitle: Text(PlanFormatting.summary(projected.spec, name: viewModel.name(for:), language: AppLanguage(locale: locale))),
            leading: {
                CircleBadge(icon: "calendar.badge.clock", fill: TLColor.neutral200, tint: TLColor.neutral600)
            },
            trailing: {
                Button {
                    Task { await viewModel.materialize(projected) }
                } label: {
                    Text("plan.addThisDay", bundle: .module)
                        .font(TLFont.zh(TLFont.rowSub, .semibold))
                        .foregroundStyle(TLColor.accent700)
                }
                .buttonStyle(.plain)
            }
        )
    }

    // MARK: - 月檢視入口

    private var monthViewEntryRow: some View {
        TLGroup {
            ListRow(
                title: localText("plan.monthView.title"),
                subtitle: Text("plan.monthView.subtitle \(viewModel.monthCompletedCount(for: viewModel.selectedDate))", bundle: .module),
                showChevron: true,
                onTap: { showingMonthView = true },
                leading: { CircleBadge(icon: "calendar", fill: TLColor.neutral200, tint: TLColor.neutral600) }
            )
        }
    }
}

/// 「月檢視」sheet：原生 `UICalendarView`，只在使用者主動要看整月分佈時才開（非預設呈現）。
private struct MonthViewSheet: View {
    @Binding var selectedDate: Date
    let markedDates: Set<Date>
    let mark: (Date) -> WeekDateStrip.DayMark

    @Environment(\.dismiss) private var dismiss

    private var selectedDayDate: Binding<DayDate> {
        Binding(
            get: { DayDate(selectedDate) },
            set: { selectedDate = $0.asDate; dismiss() }
        )
    }

    var body: some View {
        NavigationStack {
            MonthCalendarView(
                selectedDate: selectedDayDate,
                markedDates: Set(markedDates.map { DayDate($0) }),
                mark: { day in
                    switch mark(day.asDate) {
                    case .completed: .done
                    case .scheduled: .scheduled
                    case .none: nil
                    }
                }
            )
            .navigationTitle(localText("plan.monthView.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("plan.cancel") }
                }
            }
        }
        .presentationDetents([.medium])
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
