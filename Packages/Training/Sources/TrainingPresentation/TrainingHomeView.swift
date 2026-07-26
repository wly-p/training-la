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
    /// 「啟用一個循環或長期計畫」→ 切到課表分頁；nil＝不顯示這條路（例如預覽/測試環境未接線）。
    private let openSchedule: (() -> Void)?

    @State private var showsTemplatePicker = false

    public init(
        viewModel: TrainingHomeViewModel,
        makeActiveWorkoutViewModel: @escaping @MainActor (Workout) -> ActiveWorkoutViewModel,
        openSchedule: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.makeActiveWorkoutViewModel = makeActiveWorkoutViewModel
        self.openSchedule = openSchedule
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PageHeader(headerTitle, kicker: headerKicker)

                    if viewModel.resumable != nil {
                        resumableSection
                            .padding(.horizontal, TLSpace.page)
                            .padding(.top, TLSpace.section)
                    } else if hasAnyPlan {
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
    }

    // MARK: - Header

    private var hasAnyPlan: Bool { viewModel.todaysPlan != nil || !viewModel.rotations.isEmpty }

    private var headerTitle: Text { localText("training.home.title") }

    private var headerKicker: Text {
        let language = AppLanguage(locale: locale)
        let dateText = Self.kickerDateFormatter(locale: locale).string(from: Date())
        if viewModel.activePlanCount > 0 {
            let format = language.localizedString("training.home.activePlans %lld", bundle: .module)
            let suffix = String(format: format, viewModel.activePlanCount)
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

    // MARK: - 續練

    private var resumableSection: some View {
        VStack(spacing: 14) {
            localText("training.unfinished")
                .font(TLFont.zh(TLFont.rowTitle, .semibold))
                .foregroundStyle(TLColor.text)
            Button {
                viewModel.resume()
            } label: {
                localText("training.resume")
            }
            .buttonStyle(.tlPrimary)
        }
        .padding(TLSpace.rowInset)
        .frame(maxWidth: .infinity)
        .background(TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
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
                title: plan.name ?? String(localized: "training.todaysPlan", bundle: .module),
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
            Text(isToday ? String(localized: "training.home.todaySpecified", bundle: .module)
                         : String(localized: "training.home.anytime", bundle: .module))
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
                Task { await viewModel.startFromPlan() }
            } label: {
                localText("training.home.startCard")
            }
            .buttonStyle(.tlPrimary)
        case .rotation(let id):
            Button {
                Task { await viewModel.startFromRotation(id: id) }
            } label: {
                localText("training.home.startRotationCard")
            }
            .buttonStyle(.tlSecondary)
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

    private var freeTrainingLabel: String { String(localized: "training.free", bundle: .module) }

    private func setsCountText(_ count: Int) -> Text {
        let language = AppLanguage(locale: locale)
        let format = language.localizedString("training.home.setsCount %lld", bundle: .module)
        return Text(verbatim: String(format: format, count))
    }

    // MARK: - 本週

    private func weekSection(_ summary: WeekTrainingSummary) -> some View {
        VStack(alignment: .leading, spacing: TLSpace.gapM) {
            localText("training.home.thisWeek")
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(TLColor.neutral500)
            HStack(alignment: .firstTextBaseline, spacing: TLSpace.gapS) {
                Text("\(summary.sessionCount)")
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

    // MARK: - 完全沒排課（13f 右；休息日尚未實作，見 92-known-gaps）

    private var noPlanSection: some View {
        VStack(alignment: .leading, spacing: TLSpace.section) {
            EmptyState(
                systemImage: "dumbbell",
                title: String(localized: "training.noPlanToday", bundle: .module),
                message: String(localized: "training.home.noPlanMessage", bundle: .module),
                actionTitle: viewModel.templates.isEmpty ? nil : String(localized: "training.home.pickTemplateToStart", bundle: .module),
                action: { showsTemplatePicker = true }
            )
            if let lastSession = viewModel.lastSession {
                VStack(alignment: .leading, spacing: TLSpace.gapS) {
                    localText("training.home.recentlyTrained")
                        .font(TLFont.zh(TLFont.kicker, .semibold))
                        .tracking(TLFont.kickerTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(TLColor.neutral500)
                    TLGroup {
                        ListRow(
                            title: Text(verbatim: lastSession.name ?? freeTrainingLabel),
                            subtitle: Text(verbatim: "\(lastSession.day.month)/\(lastSession.day.day) · ") + setsCountText(lastSession.setCount),
                            trailing: {
                                Button {
                                    Task { await viewModel.startRepeatingLast() }
                                } label: {
                                    localText("training.home.repeatOnceMore")
                                }
                                .buttonStyle(.tlSecondary)
                                .fixedSize(horizontal: true, vertical: false)
                            }
                        )
                    }
                }
            }
            TLGroup {
                orRow(
                    icon: "plus", iconColor: TLColor.accent700,
                    title: localText("training.free") + Text(verbatim: " · ") + localText("training.home.freeTrainingHint"),
                    titleColor: TLColor.accent700,
                    trailing: nil,
                    onTap: { Task { await viewModel.startFree() } }
                )
                if let openSchedule {
                    orRow(
                        icon: "flag", iconColor: TLColor.neutral600,
                        title: localText("training.home.enableProgramHint"), titleColor: TLColor.text,
                        trailing: nil,
                        onTap: openSchedule
                    )
                }
            }
        }
    }
}
