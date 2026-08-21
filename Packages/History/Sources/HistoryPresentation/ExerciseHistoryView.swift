import Charts
import DesignSystem
import HistoryDomain
import SharedKernel
import SwiftUI

/// 單一動作歷史（04-history.md C 節：「依動作→單一動作」，圖表的唯一落點）：重量趨勢圖 ＋ PR 標記。
/// 清單頁（HistoryView 的「依動作」）只列動作名，不放圖表——點進來才看得到。
public struct ExerciseHistoryView: View {
    let option: HistoryExerciseOption
    let loadSessions: () async -> [HistoryExerciseSession]

    @State private var sessions: [HistoryExerciseSession] = []
    /// 趨勢點只在載入後算一次。
    ///
    /// 原本是 computed property，而下方的場次清單在 `ForEach` 的**每一列**都呼叫
    /// `points.first(where:)`——等於每列都重算一次整條趨勢，100 場就是 100×100 次比對，
    /// 而且每次 body 求值都重跑。
    @State private var points: [ExerciseTrendPoint] = []
    /// 場次 id → 是否創新高。取代每列 O(n) 的 `points.first(where:)` 線性搜尋。
    @State private var prSessionIds: Set<UUID> = []
    @State private var hasLoaded = false
    @Environment(\.locale) private var locale

    public init(option: HistoryExerciseOption, loadSessions: @escaping () async -> [HistoryExerciseSession]) {
        self.option = option
        self.loadSessions = loadSessions
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageHeader(Text(verbatim: option.name))

                if !hasLoaded {
                    ProgressView().padding(.top, 40).frame(maxWidth: .infinity)
                } else if points.isEmpty {
                    EmptyState(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: localString("history.exerciseTrend.empty.title", locale),
                        message: localString("history.exerciseTrend.empty.message", locale)
                    )
                    .padding(.horizontal, TLSpace.page)
                    .padding(.top, TLSpace.section)
                } else {
                    VStack(alignment: .leading, spacing: TLSpace.section) {
                        trendChart
                        sessionSection
                    }
                    .padding(.horizontal, TLSpace.page)
                    .padding(.top, TLSpace.section)
                }
            }
            .padding(.bottom, 40)
        }
        .background(TLColor.bg.ignoresSafeArea())
        .task {
            let loaded = await loadSessions()
            let trend = HistoryFormatting.trendPoints(for: loaded)
            sessions = loaded
            points = trend
            prSessionIds = Set(trend.filter(\.isPersonalRecord).map(\.id))
            hasLoaded = true
        }
    }

    // MARK: - 趨勢圖

    /// 圖表軸的識別字串。**一定要是 String 而不是字面量**——字面量會選到
    /// `PlottableValue.value(_ label: LocalizedStringKey, _:)` 那個 overload，
    /// 被 SwiftUI 的字串抽取當成待翻譯字串塞進 String Catalog（體檢 E11）。
    /// 這兩個值只是圖表內部的軸識別，不會顯示給使用者，不該進翻譯流程。
    private enum AxisID {
        static let day = "day"
        static let weight = "weight"
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(localText("history.exerciseTrend.section"))
            Chart(points) { point in
                LineMark(
                    x: .value(AxisID.day, point.day.chartDate),
                    // 一律用公斤畫，否則混單位時同一張圖會出現兩種尺度。
                    y: .value(AxisID.weight, point.weight.kilograms)
                )
                .foregroundStyle(TLColor.accent700)
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value(AxisID.day, point.day.chartDate),
                    y: .value(AxisID.weight, point.weight.kilograms)
                )
                .foregroundStyle(point.isPersonalRecord ? TLColor.sage : TLColor.accent700)
                .symbolSize(point.isPersonalRecord ? 90 : 32)
            }
            .frame(height: 200)
            .padding(TLSpace.rowInset)
            .background(TLColor.neutral100)
            .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
            HStack(spacing: 6) {
                Circle().fill(TLColor.sage).frame(width: 8, height: 8)
                localText("history.exerciseTrend.prLegend")
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral500)
            }
        }
    }

    // MARK: - 歷次場次

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(localText("history.exerciseTrend.sessions \(sessions.count)"))
            TLGroup {
                ForEach(sessions) { session in
                    ListRow(
                        title: Text(HistoryFormatting.dayLabel(session.day, locale: locale)),
                        subtitle: Text(HistoryFormatting.summary(of: session.sets)),
                        leading: {
                            if prSessionIds.contains(session.id) {
                                CircleBadge(icon: "trophy.fill", fill: TLColor.sage200, tint: TLColor.sage700)
                            } else {
                                CircleBadge(fill: TLColor.neutral200) {
                                    Text(verbatim: "\(session.day.day)")
                                        .font(TLFont.display(14))
                                        .foregroundStyle(TLColor.neutral600)
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}

extension DayDate {
    /// 圖表 x 軸只吃 `Date`；跟 Plan 套件裡同名概念一樣各自維護一份，不特別拉出去共用。
    fileprivate var chartDate: Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }
}
