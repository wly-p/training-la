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
    /// 月曆的視窗錨點。放在頁面這一層，是因為大標上方的年份 kicker 要跟著月曆走
    /// （翻到 12 月再往下一個月，年份得跳到隔年）。
    @State private var calendarAnchor: Date?
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

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
                                Label {
                                    // 長期課表尚未完成（見 ProgramListView.experimentalNotice），
                                    // 入口保留但要標明，別讓人以為是完成品。
                                    localText("plan.applyProgram")
                                        + Text(verbatim: " ")
                                        + localText("plan.applyProgram.experimental")
                                } icon: { Image(systemName: "calendar.badge.clock") }
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
            // 回前景重新載入：App 擺著過午夜後「今天」已經變了，補登邊界與投影起點都要跟著重算。
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await viewModel.load() } }
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
                // `?? ""` 會讓那個空字串變成可翻譯字面量，被抽進 String Catalog
                // 變成一個永遠不會被翻譯的空 key（體檢 E11）。改成條件式。
                if let message = viewModel.errorMessage { Text(message) }
            }
        }
    }

    // MARK: - 月曆橋接

    /// 月曆的**曆法**鎖死西曆（不跟隨裝置，避免佛曆／和曆把年份算成別的數字），
    /// 但「一週從星期幾開始」要跟隨裝置的**地區**設定。
    ///
    /// `Calendar(identifier:)` 不帶 locale，`firstWeekday` 會固定是 1（週日）——
    /// 那是搭便車跟著曆法一起被鎖死的，並非本意。結果是月曆永遠週日起算，
    /// 而訓練首頁的本週進度列原本寫死週一起算，同一個 app 兩個畫面對「一週」的定義不同。
    /// 現在兩邊都吃 `Calendar.current.firstWeekday`（台灣／美國＝週日，英國＝週一）。
    ///
    /// 顯示字串（星期縮寫、月名）仍在 View 那層依 app 語言處理，跟這裡無關。
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = Calendar.current.firstWeekday
        return calendar
    }()

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
            nextMonth: localText("plan.calendar.nextMonth")
        )
    }

    /// 大標上方的 kicker 是**年份**（`22h`）；月名在月曆自己的標題列。
    /// 跟著月曆的視窗走，翻月翻過年就會跳。
    private var monthKicker: Text {
        Text(verbatim: "\(Self.calendar.component(.year, from: calendarAnchorBinding.wrappedValue))")
    }

    // MARK: - 當天課表

    private var daySection: some View {
        let items = viewModel.workouts(on: viewModel.selectedDate)
        let projected = viewModel.projections(on: viewModel.selectedDate)
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(dayHeader(
                // 一列是一份排課，裡面可能有好幾個動作 —— 標題寫的是「動作」，
                // 就得數動作（blocks 一塊一個動作），不是數列數。
                exerciseCount: items.reduce(0) { $0 + $1.blocks.count }
                    + projected.reduce(0) { $0 + $1.spec.blocks.count }
            ))
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
