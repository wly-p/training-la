import SwiftUI

/// 月曆條（handoff-21／22）：固定六列的月檢視，沒有 sheet、沒有遮罩、沒有「取消」。
///
/// handoff-21 原本設計成「週列與月檢視是同一個元件的兩個高度」（原地展開），實測後
/// 決定不做收合 —— 課表頁常態就是整月。連帶作廢的有 grabber、收合態的換週、以及
/// handoff-22 G 節那條「一週橫跨兩個月時月名算誰的」規則（月視窗沒有這個歧義）。
///
/// 一格要同時表達四件事——是不是今天／有沒有課／做了沒／有沒有被選取。可用的視覺通道
/// 也剛好四個：填色、外框、圓圈外、圓圈下。填色與外框被課表狀態佔走，所以**今天只能長
/// 在圓圈之外**（圓下方的短槓），用填色一定會蓋掉狀態。
///
/// | 狀態 | 畫法 |
/// | --- | --- |
/// | 無課 | 純數字 `neutral-700` |
/// | 已排定 | 1.5pt `accent` 實線外框圓，數字 `accent-800` |
/// | 投影 | 同上但虛線——長期課表說這天要練，還沒按「加入這天」落地 |
/// | 已完成 | `accent` 實心圓，數字 `bg` |
/// | 今天 | 圓下方 22×4 `accent` 短槓（與 tab bar 的 active 指示同形同色）|
/// | 選取 | 圓外深墨環，`bg` 2pt ＋ `text` 2pt，外緣落在圓外 4pt |
///
/// **滑動＝瀏覽，點擊＝選取。** 滑動只移動 `anchorDate`（視窗），不動 `selectedDate`，
/// 所以下方的當日課表不會因為滑一下就換掉。離開太遠的成本由常駐的「今天」膠囊吸收。
public struct MonthDateStrip: View {
    /// 某一天的排課狀態。`projected` 是長期課表的投影（尚未落地）。
    public enum DayMark: Sendable {
        case none
        case projected
        case scheduled
        case completed
    }

    /// 這個 package 不放文字（`check-i18n.sh` 規則 2），全部由呼叫端傳 `Text` 進來。
    public struct Labels {
        public let today: Text
        public let legendCompleted: Text
        public let legendScheduled: Text
        public let legendProjected: Text
        public let legendToday: Text
        public let legendSelected: Text
        public let previousMonth: Text
        public let nextMonth: Text

        public init(
            today: Text,
            legendCompleted: Text,
            legendScheduled: Text,
            legendProjected: Text,
            legendToday: Text,
            legendSelected: Text,
            previousMonth: Text,
            nextMonth: Text
        ) {
            self.today = today
            self.legendCompleted = legendCompleted
            self.legendScheduled = legendScheduled
            self.legendProjected = legendProjected
            self.legendToday = legendToday
            self.legendSelected = legendSelected
            self.previousMonth = previousMonth
            self.nextMonth = nextMonth
        }
    }

    // MARK: - 尺寸（handoff-22 C）

    private enum Metric {
        static let circle: CGFloat = 38
        static let circleToBar: CGFloat = 8   // 選取環外緣在圓外 4pt，用 5 只剩 1pt 淨距
        static let barWidth: CGFloat = 22
        static let barHeight: CGFloat = 4
        static let rowGap: CGFloat = 8
        /// 一格的高度＝圓 ＋ 間距 ＋ 短槓。短槓空間**恆常保留**，不論那天是不是今天。
        static var cellHeight: CGFloat { circle + circleToBar + barHeight }
    }

    @Binding private var selectedDate: Date
    /// 視窗錨點：目前看的是哪一個月。滑動與 `‹ ›` 只動它。
    @Binding private var anchorDate: Date

    private let today: Date
    private let calendar: Calendar
    private let identifierPrefix: String
    private let labels: Labels
    private let mark: (Date) -> DayMark

    /// 星期縮寫與月名是系統提供的符號，不經過 String Catalog，而 `Calendar.current` /
    /// `Locale.current` 讀的是**裝置語系**，不是 app 內的語言設定。這裡改吃 Environment。
    @Environment(\.locale) private var locale

    public init(
        selectedDate: Binding<Date>,
        anchorDate: Binding<Date>,
        today: Date,
        calendar: Calendar = .current,
        identifierPrefix: String,
        labels: Labels,
        mark: @escaping (Date) -> DayMark
    ) {
        self._selectedDate = selectedDate
        self._anchorDate = anchorDate
        self.today = today
        self.calendar = calendar
        self.identifierPrefix = identifierPrefix
        self.labels = labels
        self.mark = mark
    }

    private var geometry: CalendarStripGeometry { CalendarStripGeometry(calendar: calendar) }

    /// 視窗就是一整個月，月名沒有歧義。
    private var visibleMonth: Date {
        geometry.startOfMonth(for: anchorDate) ?? anchorDate
    }

    private var rows: [[Date]] {
        let grid = geometry.monthGrid(containing: anchorDate)
        return stride(from: 0, to: grid.count, by: 7).map { Array(grid[$0..<min($0 + 7, grid.count)]) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, TLSpace.gapM)
            weekdayHeader
                .padding(.bottom, 10)
            grid
            legend.padding(.top, TLSpace.gapL)
        }
        .padding(.horizontal, TLSpace.gapL)
        // 外部（例如頁面自己改選取日）動了選取，視窗要跟過去。
        .onChange(of: selectedDate) { _, new in anchorDate = new }
    }

    // MARK: - 標題列

    private var header: some View {
        HStack(spacing: TLSpace.gapS) {
            Text(verbatim: monthName(for: visibleMonth))
                .font(TLFont.zh(19, .bold))
                .foregroundStyle(TLColor.text)
                // 「8 月」→「August」→「Août」差三倍寬，只有月名可以被壓縮；
                // 膠囊與 ‹ › 固定寬（handoff-21 F.1）。
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            todayPill.fixedSize()

            CircleIconButton(
                systemImage: "chevron.left",
                style: .neutral,
                size: TLSize.iconButtonSmall,
                iconSize: 15,
                iconWeight: .bold
            ) { step(-1) }
                .accessibilityLabel(labels.previousMonth)
                .accessibilityIdentifier("\(identifierPrefix).prev")

            CircleIconButton(
                systemImage: "chevron.right",
                style: .neutral,
                size: TLSize.iconButtonSmall,
                iconSize: 15,
                iconWeight: .bold
            ) { step(1) }
                .accessibilityLabel(labels.nextMonth)
                .accessibilityIdentifier("\(identifierPrefix).next")
        }
    }

    /// 「今天」膠囊**永遠存在**（handoff-22 E）。原本只在「迷路」時出現，出現／消失會讓
    /// `‹ ›` 左右位移；常駐之後標題列不跳版，也不用再算「現在算不算迷路」。
    /// 已經在今天時仍然可按 —— 它跟 `‹ ›` 同材質，是導航組的一員，導航鍵沒有
    /// 「按了沒事就是壞了」的預期。
    private var todayPill: some View {
        Button {
            selectedDate = today
            anchorDate = today
        } label: {
            labels.today
                .font(TLFont.zh(12.5, .semibold))
                .foregroundStyle(TLColor.text)
                .padding(.horizontal, 15)
                .frame(height: 34)
                .background(TLColor.neutral200)
                .clipShape(Capsule())
                .frame(minHeight: TLSize.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(identifierPrefix).today")
    }

    // MARK: - 格線

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(verbatim: symbol)
                    .font(TLFont.zh(TLFont.kicker, .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(TLColor.neutral500)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        VStack(spacing: Metric.rowGap) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 0) {
                    ForEach(rows[index], id: \.self) { cell(for: $0) }
                }
            }
        }
        .contentShape(Rectangle())
        // 滑動只換視窗，不換選取日：月曆下面直接接當日課表，滑動若改選取，
        // 「看看下個月排了什麼」這個純瀏覽動作會一路改掉使用者的選取。
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                if value.translation.width < 0 { step(1) }
                else if value.translation.width > 0 { step(-1) }
            }
        )
    }

    private func cell(for day: Date) -> some View {
        let isOverflow = geometry.isOverflow(day, in: visibleMonth)
        let state = isOverflow ? DayMark.none : mark(day)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)

        return VStack(spacing: Metric.circleToBar) {
            ZStack {
                shape(for: state)
                Text(verbatim: "\(calendar.component(.day, from: day))")
                    .font(TLFont.display(15))
                    .foregroundStyle(numberColor(state: state, isOverflow: isOverflow))
            }
            .frame(width: Metric.circle, height: Metric.circle)
            .overlay { if isSelected { selectionRing } }

            // 非今天時仍保留短槓的位置，否則有今天的那一列會比其他列高 12pt，
            // 切月時今天進出畫面會讓版面上下抽動。與 TLTabBar 的 active 指示同一招。
            Capsule()
                .fill(isToday ? TLColor.accent : Color.clear)
                .frame(width: Metric.barWidth, height: Metric.barHeight)
        }
        .frame(maxWidth: .infinity, minHeight: Metric.cellHeight)
        // 點擊區是整格，不是 38pt 的圓 —— 只掛在圓上會低於 44pt 最小觸控。
        .contentShape(Rectangle())
        .onTapGesture {
            // 點上／下月的溢出日：選取該日並自動跳到該月（anchor 一起移過去）。
            selectedDate = day
            anchorDate = day
        }
        .accessibilityIdentifier("\(identifierPrefix).day.\(identifierKey(for: day))")
    }

    @ViewBuilder
    private func shape(for state: DayMark) -> some View {
        switch state {
        case .completed:
            Circle().fill(TLColor.accent)
        case .scheduled:
            Circle().strokeBorder(TLColor.accent, lineWidth: 1.5)
        case .projected:
            // 實線＝已排定（真的排了），虛線＝長期課表說這天要練但還沒按「加入這天」。
            Circle().strokeBorder(
                TLColor.accent,
                style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
            )
        case .none:
            EmptyView()
        }
    }

    private func numberColor(state: DayMark, isOverflow: Bool) -> Color {
        if isOverflow { return TLColor.neutral400 }
        switch state {
        case .completed: return TLColor.bg
        case .scheduled, .projected: return TLColor.accent800
        case .none: return TLColor.neutral700
        }
    }

    /// 圓外的深墨環：`bg` 2pt 墊出淨距，再 `text` 2pt，外緣落在圓外 4pt。
    private var selectionRing: some View {
        ZStack {
            Circle()
                .strokeBorder(TLColor.bg, lineWidth: 2)
                .frame(width: Metric.circle + 4, height: Metric.circle + 4)
            Circle()
                .strokeBorder(TLColor.text, lineWidth: 2)
                .frame(width: Metric.circle + 8, height: Metric.circle + 8)
        }
    }

    // MARK: - 圖例與 grabber

    /// 六種畫法全靠形狀區分，沒有文字的話「實線圓 vs 虛線圓」要自己猜。
    /// 英文的長標籤要能換行（handoff-21 F.4）。
    private var legend: some View {
        FlowLayout(spacing: 16, lineSpacing: TLSpace.gapS) {
            legendItem(labels.legendCompleted) {
                Circle().fill(TLColor.accent).frame(width: 12, height: 12)
            }
            legendItem(labels.legendScheduled) {
                Circle().strokeBorder(TLColor.accent, lineWidth: 1.5).frame(width: 12, height: 12)
            }
            legendItem(labels.legendProjected) {
                Circle()
                    .strokeBorder(TLColor.accent, style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5]))
                    .frame(width: 12, height: 12)
            }
            legendItem(labels.legendToday) {
                Capsule().fill(TLColor.accent).frame(width: 14, height: 3.5)
            }
            legendItem(labels.legendSelected) {
                Circle().strokeBorder(TLColor.text, lineWidth: 1.5).frame(width: 12, height: 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(_ label: Text, @ViewBuilder swatch: () -> some View) -> some View {
        HStack(spacing: 6) {
            swatch().fixedSize()
            label
                .font(TLFont.zh(TLFont.rowSub, .regular))
                .foregroundStyle(TLColor.neutral600)
        }
        .fixedSize()
    }

    // MARK: - 視窗移動

    private func step(_ delta: Int) {
        guard let moved = calendar.date(byAdding: .month, value: delta, to: anchorDate) else { return }
        withAnimation(.easeOut(duration: 0.2)) { anchorDate = moved }
    }

    // MARK: - 系統符號

    /// 星期標頭：中文要一個字（`日 一 二 …`，設計稿 `22h`），英文要三個字母（`SUN`）。
    ///
    /// 判斷方式不是「是不是中文」，而是**七格分不分得出來**：`veryShort` 在中文是
    /// 日一二三四五六（七個都不同，可用），在英文是 S M T W T F S（週日與週六、週二與
    /// 週四撞在一起，不可用），這時退回 `short` 的 Sun／Mon。標頭的職責就是可分辨，
    /// 拿這個當條件比拿語系當條件準確。
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        let short = formatter.shortWeekdaySymbols ?? []
        let veryShort = formatter.veryShortWeekdaySymbols ?? []
        let symbols = (veryShort.count == 7 && Set(veryShort).count == 7) ? veryShort : short
        guard symbols.count == 7 else { return symbols }
        let first = calendar.firstWeekday - 1
        return (0..<7).map { symbols[($0 + first) % 7] }
    }

    private func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }

    /// UI test 定位用的鍵。刻意不經過 `DateFormatter` —— 這是識別字不是顯示字串，
    /// 不能跟著語系變。
    private func identifierKey(for day: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
