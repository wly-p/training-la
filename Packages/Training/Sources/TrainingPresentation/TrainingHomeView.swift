import DesignSystem
import SharedKernel
import SwiftUI
import TrainingDomain

/// 訓練首頁（設計稿 6b）：橫向卡片捲軸（今天指定／隨時可做）＋「或者」群組＋本週進度。
/// 完全沒排課／有未結束場次時換成對應的空狀態／續練提示。
public struct TrainingHomeView: View {
    @Bindable private var viewModel: TrainingHomeViewModel
    @Environment(\.locale) private var locale
    private let makeActiveWorkoutViewModel: @MainActor (Workout) -> ActiveWorkoutViewModel
    /// 「啟用一個循環或長期計畫」／13d「只調這一次」→ 切到課表分頁；nil＝不顯示這條路。
    private let openSchedule: (() -> Void)?
    /// 13d「改範本」→ 切到動作庫分頁（範本/循環/長期的編輯都在那裡）；nil＝不顯示這條路。
    private let openLibrary: (() -> Void)?

    @State private var showsTemplatePicker = false

    public init(
        viewModel: TrainingHomeViewModel,
        makeActiveWorkoutViewModel: @escaping @MainActor (Workout) -> ActiveWorkoutViewModel,
        openSchedule: (() -> Void)? = nil,
        openLibrary: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.makeActiveWorkoutViewModel = makeActiveWorkoutViewModel
        self.openSchedule = openSchedule
        self.openLibrary = openLibrary
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PageHeader(headerTitle, kicker: headerKicker)

                    if hasAnyPlan {
                        carousel
                            .padding(.top, TLSpace.section)
                        if cards.count > 1 {
                            pageDots.padding(.top, TLSpace.gapM)
                        }
                        orGroup
                            .padding(.horizontal, TLSpace.page)
                            .padding(.top, TLSpace.section)
                        if let weekSummary = viewModel.weekSummary {
                            weekSection(weekSummary)
                                .padding(.horizontal, TLSpace.page)
                                .padding(.top, TLSpace.section)
                        }
                    } else if let restDay = viewModel.restDay {
                        restDaySection(restDay)
                            .padding(.horizontal, TLSpace.page)
                            .padding(.top, TLSpace.section)
                    } else {
                        noPlanSection
                            .padding(.horizontal, TLSpace.page)
                            .padding(.top, TLSpace.section)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(TLColor.bg.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .task { await viewModel.refresh() }
            .sheet(item: $viewModel.recording, onDismiss: {
                Task { await viewModel.refresh() }
            }) { workout in
                ActiveWorkoutView(viewModel: makeActiveWorkoutViewModel(workout))
                    .interactiveDismissDisabled()
            }
            .sheet(item: $viewModel.pendingStart) { pending in
                TrainingPreviewSheet(
                    blueprint: pending.blueprint,
                    comparison: pending.comparison,
                    onStart: { Task { await viewModel.confirmPendingStart() } },
                    onAdjustOnce: openSchedule,
                    onEditTemplate: openLibrary
                )
            }
            .confirmationDialog(
                localText("training.chooseTemplate"),
                isPresented: $showsTemplatePicker,
                titleVisibility: .visible
            ) {
                ForEach(viewModel.templates) { template in
                    Button {
                        Task { await viewModel.startFromTemplate(id: template.id) }
                    } label: {
                        // 範本名是使用者資料（verbatim）
                        Text(verbatim: template.name)
                    }
                }
            }
            .alert(
                localText("training.error"),
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.dismissError() } }
                )
            ) {
                Button(role: .cancel) {} label: { localText("training.ok") }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        // 中斷後恢復（13b）：用 overlay 蓋滿全螢幕（跟 ActiveWorkoutView 的完成卡片同一個模式），
        // 不用 .sheet——這是「一次性攔截」的對話框，不是可以滑掉的內容頁，且避免跟其他
        // sheet（開練前預覽等）疊放時的 dismiss race。
        .overlay {
            if let summary = viewModel.resumeSummary {
                resumeDialog(summary)
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.resumeSummary != nil)
    }

    // MARK: - Header

    private var hasAnyPlan: Bool { viewModel.todaysPlan != nil || !viewModel.rotations.isEmpty }

    private var headerTitle: Text {
        if hasAnyPlan { return localText("training.home.title") }
        if viewModel.restDay != nil { return localText("training.home.restDay.title") }
        // 13f 右：主標直接寫結論，卡片標題（「你目前沒有進行中的計畫」）才是另一句話。
        return localText("training.noPlanToday")
    }

    /// `M / D 週X`，有狀態才接 `· xxx`（進行中計畫數／休息日）。
    private var headerKicker: Text {
        let language = AppLanguage(locale: locale)
        let dateText = Self.kickerDateFormatter(locale: locale).string(from: Self.date(of: viewModel.todayDate))
        if viewModel.activePlanCount > 0 {
            let format = language.localizedString("training.home.activePlans %lld", bundle: .module)
            let suffix = String(format: format, viewModel.activePlanCount)
            return Text(verbatim: "\(dateText) · \(suffix)")
        }
        if viewModel.restDay != nil {
            let suffix = language.localizedString("training.home.kicker.restDay", bundle: .module)
            return Text(verbatim: "\(dateText) · \(suffix)")
        }
        return Text(verbatim: dateText)
    }

    private static func kickerDateFormatter(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("M/d EEEE")
        return formatter
    }

    /// `DayDate` 刻意不對外暴露底層 `Date` 換算（見 SharedKernel 的註解），這裡自己補一個。
    private static func date(of day: DayDate) -> Date {
        Calendar(identifier: .gregorian)
            .date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? Date()
    }

    // MARK: - 續練

    // MARK: - 中斷後恢復（13b）

    @State private var showsDiscardResumableConfirm = false

    /// 置中對話框：昨天/今天那場還開著。隔夜（>看 day 是否為今天）「結束它」當預設主按鈕；
    /// 當天中斷則「繼續」當預設——同一份 layout，只是主／次按鈕角色對調。
    private func resumeDialog(_ summary: ResumeSummary) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text(summary.isOvernight
                    ? localString("training.resume.overnightTitle", locale)
                    : localString("training.resume.sameDayTitle", locale))
                    .font(TLFont.zh(20, .bold))
                    .foregroundStyle(TLColor.text)
                Text(verbatim: resumeDescription(summary))
                    .font(.footnote)
                    .foregroundStyle(TLColor.neutral600)

                VStack(spacing: 10) {
                    HStack {
                        statNumber("\(summary.recordedSetCount)", label: "training.resume.recordedSets")
                        Spacer()
                        if let remaining = summary.remainingSetCount {
                            statNumber("\(remaining)", label: "training.resume.remainingSets")
                            Spacer()
                        }
                        statNumber("\(summary.elapsedMinutes)", label: "training.finish.minutes")
                    }
                    Text(verbatim: String(
                        format: localString("training.resume.dataStaysPut %lld", locale),
                        summary.recordedSetCount
                    ))
                    .font(.caption2)
                    .foregroundStyle(TLColor.neutral600)
                }
                .padding(TLSpace.rowInset)
                .background(TLColor.neutral300)
                .clipShape(RoundedRectangle(cornerRadius: TLRadius.inner, style: .continuous))

                resumeActions(summary)
            }
            .padding(TLSpace.page)
            .background(TLColor.neutral100)
            .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
            .tlShadow(TLShadow.lg)
            .padding(.horizontal, TLSpace.page)
        }
        .confirmationDialog(
            localText("training.resume.discardConfirmTitle"),
            isPresented: $showsDiscardResumableConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                Task { await viewModel.discardResumable() }
            } label: {
                localText("training.resume.discardConfirm")
            }
        }
    }

    private func resumeDescription(_ summary: ResumeSummary) -> String {
        guard let start = summary.workout.startedAt else { return "" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        let name = summary.name ?? localString("training.free", locale)
        return String(
            format: localString("training.resume.description %@ %@", locale),
            name, formatter.string(from: start)
        )
    }

    private func statNumber(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(TLFont.display(26))
                .foregroundStyle(TLColor.text)
            Text(LocalizedStringKey(label), bundle: .module)
                .font(.caption2)
                .foregroundStyle(TLColor.neutral600)
        }
    }

    @ViewBuilder private func resumeActions(_ summary: ResumeSummary) -> some View {
        let endButton = Button {
            Task { await viewModel.endResumableNow() }
        } label: {
            localText("training.resume.endNow")
        }
        let continueButton = Button {
            viewModel.resume()
        } label: {
            if let remaining = summary.remainingSetCount {
                Text(verbatim: String(format: localString("training.resume.continueRemaining %lld", locale), remaining))
            } else {
                localText("training.resume.continue")
            }
        }
        VStack(spacing: 10) {
            if summary.isOvernight {
                endButton.buttonStyle(.tlPrimary)
                continueButton.buttonStyle(.tlSecondary)
            } else {
                continueButton.buttonStyle(.tlPrimary)
                endButton.buttonStyle(.tlSecondary)
            }
            Button {
                showsDiscardResumableConfirm = true
            } label: {
                localText("training.resume.discard")
            }
            .buttonStyle(.tlDestructiveText)
        }
    }

    // MARK: - 卡片捲軸

    private enum CardKind: Equatable { case todaySpecified, rotation(UUID) }

    private struct Card: Identifiable {
        let id: String
        let kind: CardKind
        let title: String
        let subtitle: String?
        let meta: String?
    }

    private var cards: [Card] {
        var result: [Card] = []
        if let plan = viewModel.todaysPlan {
            let totalSets = plan.exercises.reduce(0) { $0 + $1.setCount }
            let language = AppLanguage(locale: locale)
            let format = language.localizedString("training.home.exerciseSetCount %lld %lld", bundle: .module)
            result.append(Card(
                id: "today",
                kind: .todaySpecified,
                title: plan.name ?? localString("training.todaysPlan", locale),
                subtitle: nil,
                meta: String(format: format, plan.exercises.count, totalSets)
            ))
        }
        for rotation in viewModel.rotations {
            result.append(Card(
                id: rotation.id.uuidString,
                kind: .rotation(rotation.id),
                title: rotation.currentName,
                subtitle: rotation.rotationName,
                meta: nil
            ))
        }
        return result
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(cards) { card in
                    cardView(card)
                }
            }
            .padding(.leading, TLSpace.page)
            .padding(.trailing, TLSpace.page)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrolledCardId)
        .scrollTargetBehavior(.viewAligned)
    }

    @State private var scrolledCardId: String?

    private var pageDots: some View {
        HStack(spacing: 5) {
            ForEach(cards) { card in
                Capsule()
                    .fill((scrolledCardId ?? cards.first?.id) == card.id ? TLColor.accent : TLColor.neutral300)
                    .frame(width: (scrolledCardId ?? cards.first?.id) == card.id ? 20 : 5, height: 5)
            }
        }
        .padding(.horizontal, TLSpace.page)
    }

    private func cardView(_ card: Card) -> some View {
        let isToday = card.kind == .todaySpecified
        return VStack(alignment: .leading, spacing: TLSpace.gapS) {
            Text(isToday ? localString("training.home.todaySpecified", locale)
                         : localString("training.home.anytime", locale))
                .font(TLFont.zh(11, .semibold))
                .foregroundStyle(isToday ? TLColor.accent800 : TLColor.neutral800)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isToday ? TLColor.accent200 : TLColor.neutral300)
                .clipShape(Capsule())

            Text(verbatim: card.title)
                .font(TLFont.zh(20, .bold))
                .foregroundStyle(TLColor.text)
                .lineLimit(2)

            if let subtitle = card.subtitle {
                Text(verbatim: subtitle)
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral500)
            }
            if let meta = card.meta {
                Text(verbatim: meta)
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral600)
            }

            Spacer(minLength: TLSpace.gapM)

            cardButton(card)
        }
        .padding(TLSpace.rowInset)
        .frame(width: 242, alignment: .leading)
        .frame(minHeight: 190)
        .background(isToday ? TLColor.neutral100 : TLColor.neutral100.opacity(0.6))
        .overlay {
            RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous)
                .strokeBorder(isToday ? TLColor.accent300 : Color.clear, lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
        .id(card.id)
    }

    @ViewBuilder private func cardButton(_ card: Card) -> some View {
        switch card.kind {
        case .todaySpecified:
            Button {
                viewModel.previewPlan()
            } label: {
                localText("training.home.startCard")
            }
            .buttonStyle(.tlPrimary)
            .accessibilityIdentifier("training.startCard")
        case .rotation(let id):
            Button {
                Task { await viewModel.previewRotation(id: id) }
            } label: {
                localText("training.home.startRotationCard")
            }
            .buttonStyle(.tlSecondary)
            .accessibilityIdentifier("training.startRotation")
        }
    }

    // MARK: - 或者

    private var orGroup: some View {
        TLGroup {
            orRow(
                icon: "plus", iconColor: TLColor.accent700,
                title: localText("training.free"), titleColor: TLColor.accent700,
                trailing: nil,
                onTap: { Task { await viewModel.startFree() } }
            )
            if let lastSession = viewModel.lastSession {
                orRow(
                    icon: "arrow.counterclockwise", iconColor: TLColor.neutral600,
                    title: localText("training.home.repeatLast"), titleColor: TLColor.text,
                    trailing: Text(verbatim: "\(lastSession.day.month)/\(lastSession.day.day) \(lastSession.name ?? freeTrainingLabel)"),
                    onTap: { Task { await viewModel.startRepeatingLast() } }
                )
            }
        }
    }

    private func orRow(
        icon: String,
        iconColor: Color,
        title: Text,
        titleColor: Color,
        trailing: Text?,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: TLSpace.gapM) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: TLSize.badge)
                title
                    .font(TLFont.zh(TLFont.rowTitle, .semibold))
                    .foregroundStyle(titleColor)
                Spacer(minLength: TLSpace.gapS)
                if let trailing {
                    trailing
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                }
            }
            .padding(.horizontal, TLSpace.rowInset)
            .frame(minHeight: TLSize.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var freeTrainingLabel: String { localString("training.free", locale) }

    // MARK: - 本週

    private func weekSection(_ summary: WeekTrainingSummary) -> some View {
        VStack(alignment: .leading, spacing: TLSpace.gapM) {
            localText("training.home.thisWeek")
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(TLColor.neutral500)
            HStack(alignment: .firstTextBaseline, spacing: TLSpace.gapS) {
                Text(verbatim: "\(summary.sessionCount)")
                    .font(TLFont.display(34))
                    .foregroundStyle(TLColor.text)
                weekDurationText(summary.totalMinutes)
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral600)
            }
            WeekProgressRow(days: summary.days)
        }
    }

    /// 大數字（次數）後面接的文字：「次訓練 · 累計2小時10分」。次數已經是大數字本身，這裡不重複。
    private func weekDurationText(_ totalMinutes: Int) -> Text {
        let language = AppLanguage(locale: locale)
        let durationFormat = language.localizedString("training.home.weekDuration %lld %lld", bundle: .module)
        let duration = String(format: durationFormat, totalMinutes / 60, totalMinutes % 60)
        return localText("training.home.weekSessionsLabel") + Text(verbatim: " · \(duration)")
    }

    // MARK: - 今天休息（13f 左）

    private func restDaySection(_ restDay: RestDayInfo) -> some View {
        VStack(alignment: .leading, spacing: TLSpace.section) {
            VStack(alignment: .leading, spacing: TLSpace.gapM) {
                ZStack {
                    Circle().fill(Color.white)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(TLColor.sage700)
                }
                .frame(width: 52, height: 52)

                // 課表名是使用者資料（verbatim），套進本地化模板組成整句。
                Text(verbatim: String(
                    format: localString("training.home.restDay.headline %@ %@", locale),
                    restDay.programName, cyclePositionText(restDay)
                ))
                .font(TLFont.zh(16, .bold))
                .foregroundStyle(TLColor.text)

                Text(verbatim: restDayRecapText(restDay))
                    .font(TLFont.zh(12.5, .regular))
                    .foregroundStyle(TLColor.sage800)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TLSpace.page)
            .padding(.vertical, 22)
            .background(TLColor.sage200)
            .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))

            VStack(alignment: .leading, spacing: TLSpace.gapS) {
                TLGroup {
                    orRow(
                        icon: "flame.fill", iconColor: TLColor.accent700,
                        title: localText("training.home.restDay.startAnyway"), titleColor: TLColor.accent700,
                        trailing: nil,
                        onTap: { Task { await viewModel.startFree() } }
                    )
                    // 下一個訓練日存在才給得出「把 X 挪到今天」——沒有下一場就沒得挪。
                    if let moveTitle = moveHereTitle(restDay) {
                        orRow(
                            icon: "arrow.left.arrow.right", iconColor: TLColor.neutral600,
                            title: Text(verbatim: moveTitle), titleColor: TLColor.text,
                            trailing: nil,
                            onTap: { Task { await viewModel.moveNextWorkoutToToday() } }
                        )
                        .accessibilityIdentifier("training.moveNextWorkoutHere")
                    }
                }
                if moveHereTitle(restDay) != nil {
                    // 健身房的臨時應變不該回頭改壞課表節奏，這句話要寫出來。
                    localText("training.home.restDay.moveHint")
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                        .padding(.horizontal, TLSpace.rowInset)
                }
            }

            if let weekSummary = viewModel.weekSummary {
                weekSection(weekSummary)
            }
        }
    }

    /// 綠卡主句後半段：repeating 有輪次就寫「第 7 輪 D3」，否則只寫「D3」。
    private func cyclePositionText(_ restDay: RestDayInfo) -> String {
        guard let round = restDay.roundNumber else {
            return String(format: localString("training.home.restDay.day %lld", locale), restDay.dayNumber)
        }
        return String(
            format: localString("training.home.restDay.round %lld %lld", locale), round, restDay.dayNumber
        )
    }

    /// 綠卡副句：下一個訓練日 ＋ 本週已練的次數與總量（`明天是「腿日」。這週已經練了 3 次、9,140 kg。`）。
    private func restDayRecapText(_ restDay: RestDayInfo) -> String {
        var parts = [nextWorkoutText(restDay)]
        if let week = viewModel.weekSummary, week.sessionCount > 0 {
            parts.append(String(
                format: localString("training.home.restDay.weekRecap %lld %@", locale),
                week.sessionCount, WeightDisplay.value(week.totalVolume)
            ))
        }
        return parts.joined(separator: " ")
    }

    /// 「把明天的腿日挪到今天」；不是明天就寫出日期。沒有下一個訓練日＝nil，整列不出現。
    private func moveHereTitle(_ restDay: RestDayInfo) -> String? {
        guard let date = restDay.nextWorkoutDate, let name = restDay.nextWorkoutName else { return nil }
        if date == viewModel.todayDate.adding(days: 1) {
            return String(format: localString("training.home.restDay.moveTomorrow %@", locale), name)
        }
        return String(
            format: localString("training.home.restDay.moveLater %@ %@", locale),
            "\(date.month)/\(date.day)", name
        )
    }

    /// 下一個訓練日文案：明天/未來某天有排課就報日期＋名稱；once 模式已經跑完週期就誠實說沒有了。
    private func nextWorkoutText(_ restDay: RestDayInfo) -> String {
        guard let date = restDay.nextWorkoutDate, let name = restDay.nextWorkoutName else {
            return localString("training.home.restDay.noMoreWorkouts", locale)
        }
        if date == viewModel.todayDate.adding(days: 1) {
            return String(format: localString("training.home.restDay.nextWorkoutTomorrow %@", locale), name)
        }
        let dateText = "\(date.month)/\(date.day)"
        return String(format: localString("training.home.restDay.nextWorkoutLater %@ %@", locale), dateText, name)
    }

    // MARK: - 完全沒排課（13f 右）

    private var noPlanSection: some View {
        VStack(alignment: .leading, spacing: TLSpace.section) {
            // 卡片裡不放按鈕（01-training A 節）：動作一律降到下方的群組清單，
            // 否則這張沙卡跟休息日那張綠卡高度不一樣、視覺重量也不對等。
            // 「今天沒有排課」這張沙卡，測試用它驗排課有沒有被標成完成／還原。
            // id 掛在卡片上而不是整個 section——套在容器上會讓它變成單一無障礙元素，
            // 底下的按鈕整批查不到。
            EmptyState(
                systemImage: "waveform.path.ecg",
                title: localString("training.home.noPlan.cardTitle", locale),
                message: localString("training.home.noPlanMessage", locale)
            )
            .accessibilityIdentifier("training.noPlanCard")

            if !viewModel.recentSessions.isEmpty { recentSessionsSection }

            TLGroup {
                if !viewModel.templates.isEmpty {
                    orRow(
                        icon: "square.grid.2x2", iconColor: TLColor.accent700,
                        title: localText("training.home.pickTemplateToStart"), titleColor: TLColor.accent700,
                        trailing: nil,
                        onTap: { showsTemplatePicker = true }
                    )
                    .accessibilityIdentifier("training.pickTemplateToStart")
                }
                orRow(
                    icon: "plus", iconColor: TLColor.accent700,
                    title: localText("training.free") + Text(verbatim: " · ") + localText("training.home.freeTrainingHint"),
                    titleColor: TLColor.accent700,
                    trailing: nil,
                    onTap: { Task { await viewModel.startFree() } }
                )
                .accessibilityIdentifier("training.startFree")
                if let openSchedule {
                    orRow(
                        icon: "flag", iconColor: TLColor.neutral600,
                        title: localText("training.home.enableProgramHint"), titleColor: TLColor.text,
                        trailing: nil,
                        onTap: openSchedule
                    )
                }
            }

            // 「這週」在有排課與休息日兩條路徑都會顯示，沒排課時卻整塊不見——但這個區塊講的是
            // 本週練了幾次，跟今天有沒有排課無關。沒排課的人反而更需要看到進度。
            if let weekSummary = viewModel.weekSummary {
                weekSection(weekSummary)
            }
        }
    }

    /// 「最近練過」（13f 右）：冷啟動之外的人，這是最短的一條出路——上次練的那份再來一次。
    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapM) {
            localText("training.home.recentlyTrained")
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(TLColor.neutral500)
            TLGroup {
                ForEach(viewModel.recentSessions) { session in
                    recentSessionRow(session)
                }
            }
        }
    }

    private func recentSessionRow(_ session: RecentSessionSummary) -> some View {
        HStack(spacing: TLSpace.gapS) {
            VStack(alignment: .leading, spacing: 2) {
                // 範本名是使用者資料（verbatim）。
                Text(verbatim: session.name ?? freeTrainingLabel)
                    .font(TLFont.zh(TLFont.rowTitle, .semibold))
                    .foregroundStyle(TLColor.text)
                Text(verbatim: recentSessionSubtitle(session))
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral500)
            }
            Spacer(minLength: TLSpace.gapS)
            Button {
                Task { await viewModel.startRepeating(session) }
            } label: {
                localText("training.home.trainAgain")
            }
            // 列內動作的尺寸，不是頁面級 CTA——tlSecondary 的高度會把 56pt 的列撐滿。
            .buttonStyle(.tlSecondarySmall)
            // 「再練一次」不能被壓成兩行，寬度讓給它、由左邊的名稱先截斷。
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("training.trainAgain")
        }
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: TLSize.row)
    }

    /// `昨天 · 13 組 · 72 分`；不是昨天就寫日期，算不出時長就只到組數。
    private func recentSessionSubtitle(_ session: RecentSessionSummary) -> String {
        let today = viewModel.todayDate
        let dayText = session.day == today.adding(days: -1)
            ? localString("training.home.yesterday", locale)
            : "\(session.day.month)/\(session.day.day)"
        var parts = [dayText, String(format: localString("training.home.setCount %lld", locale), session.setCount)]
        if let minutes = session.minutes {
            parts.append(String(format: localString("training.home.minuteCount %lld", locale), minutes))
        }
        return parts.joined(separator: " · ")
    }
}
