import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

/// 課表分頁（設計稿 `21a` / `22h` / `22j`）：週列與月檢視是 `MonthDateStrip` 的兩個高度，
/// 原地展開，沒有 sheet、沒有遮罩、沒有「取消」。預設是收合的一列（`22j`）。
public struct PlanScheduleView: View {
    @Bindable private var viewModel: PlanScheduleViewModel
    @State private var editing: PlanFormTarget?
    @State private var pickingTemplate = false
    @State private var applyingProgram = false
    /// 月曆的視窗錨點與展開狀態。錨點放在頁面這一層，是因為大標上方的年份 kicker
    /// 要跟著月名走（收合滑到 12/27–1/2 時年份也得跳）。
    @State private var calendarAnchor: Date?
    @State private var calendarExpanded = false
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
                            .accessibilityIdentifier("plan.addBlank")
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
                            .accessibilityIdentifier("plan.applyProgram")
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(TLColor.bg)
                                .frame(width: TLSize.iconButton, height: TLSize.iconButton)
                                .background(TLColor.accent)
                                .clipShape(Capsule())
                        }
                        .accessibilityLabel(localText("plan.new"))
                        .accessibilityIdentifier("plan.new")
                    }

                    MonthDateStrip(
                        selectedDate: selectedDateBinding,
                        anchorDate: calendarAnchorBinding,
                        isExpanded: $calendarExpanded,
                        today: viewModel.today.asDate,
                        calendar: Self.calendar,
                        identifierPrefix: "plan.calendar",
                        labels: calendarLabels,
                        mark: { calendarMark(for: DayDate($0)) }
                    )
                    .padding(.top, TLSpace.gapM)

                    daySection
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

    // MARK: - 月曆橋接

    /// 月曆的日期運算用固定的西曆，只有「顯示字串」才吃 locale（星期縮寫、月名）。
    private static let calendar = Calendar(identifier: .gregorian)

    /// `MonthDateStrip` 只吃 `Date`；`PlanScheduleViewModel.selectedDate` 是 `DayDate`
    /// （見 SharedKernel：純日曆日，避免時區把日期偏移一天），這裡互轉。
    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.selectedDate.asDate },
            set: { viewModel.selectedDate = DayDate($0) }
        )
    }

    /// 錨點的初值＝選取日；之後由月曆自己推動（滑動只動它、點格子與「今天」一起動）。
    private var calendarAnchorBinding: Binding<Date> {
        Binding(
            get: { calendarAnchor ?? viewModel.selectedDate.asDate },
            set: { calendarAnchor = $0 }
        )
    }

    /// 四種狀態一對一。`projected` 不再壓成 `scheduled` —— 長期課表說這天要練、但還沒按
    /// 「加入這天」落地，畫成虛線外框才不會讓建議看起來像已確定的排課。
    private func calendarMark(for date: DayDate) -> MonthDateStrip.DayMark {
        switch viewModel.mark(on: date) {
        case .done: .completed
        case .scheduled: .scheduled
        case .projected: .projected
        case nil: .none
        }
    }

    private var calendarLabels: MonthDateStrip.Labels {
        MonthDateStrip.Labels(
            today: localText("plan.calendar.today"),
            legendCompleted: localText("plan.calendar.legend.completed"),
            legendScheduled: localText("plan.calendar.legend.scheduled"),
            legendProjected: localText("plan.calendar.legend.projected"),
            legendToday: localText("plan.calendar.legend.today"),
            legendSelected: localText("plan.calendar.legend.selected"),
            previousMonth: localText("plan.calendar.prevMonth"),
            nextMonth: localText("plan.calendar.nextMonth"),
            expand: localText("plan.calendar.expand"),
            collapse: localText("plan.calendar.collapse")
        )
    }

    /// 大標上方的 kicker 是**年份**（`22h`）；月名移進月曆的標題列。
    /// 跟著月曆顯示的月走，所以收合滑到跨年的那一週時年份也會跳。
    private var monthKicker: Text {
        let month = MonthDateStrip.displayedMonth(
            anchor: calendarAnchorBinding.wrappedValue,
            selection: viewModel.selectedDate.asDate,
            isExpanded: calendarExpanded,
            calendar: Self.calendar
        )
        return Text(verbatim: "\(Self.calendar.component(.year, from: month))")
    }

    // MARK: - 當天課表

    private var daySection: some View {
        let items = viewModel.workouts(on: viewModel.selectedDate)
        let projected = viewModel.projections(on: viewModel.selectedDate)
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(dayHeader(exerciseCount: items.count + projected.count))
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

    /// 「8 / 15 週五 · 2 個動作」（設計稿 `22h`）。沒有動作時只留日期，不顯示「0 個動作」。
    private func dayHeader(exerciseCount: Int) -> Text {
        let day = PlanFormatting.dayLabel(viewModel.selectedDate, locale: locale)
        guard exerciseCount > 0 else { return Text(verbatim: day) }
        let count = String(format: localString("plan.day.count %lld", locale), exerciseCount)
        return Text(verbatim: "\(day) · \(count)")
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
                .accessibilityIdentifier("plan.addThisDay")
            }
        )
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
