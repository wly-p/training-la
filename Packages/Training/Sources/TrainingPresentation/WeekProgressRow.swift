import DesignSystem
import Foundation
import SharedKernel
import SwiftUI
import TrainingDomain

/// 「這週」7 圓進度環（6b／13f 共用）：已練＝赭紅實心＋白勾、未練＝neutral-200、
/// 今天＝1.5px 虛線 accent-300 外框。純顯示，不含互動。
struct WeekProgressRow: View {
    let days: [WeekTrainingSummary.Day]

    /// 星期縮寫走系統符號，`Calendar.current` 讀的是裝置語系而非 app 語言設定，要吃 Environment。
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(weekdaySymbol(for: day.date))
                        .font(TLFont.zh(10, .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(TLColor.neutral500)
                    ZStack {
                        if day.completed {
                            Circle().fill(TLColor.accent)
                        } else if day.isToday {
                            Circle().strokeBorder(TLColor.accent300, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        } else {
                            Circle().fill(TLColor.neutral200)
                        }
                        if day.completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(TLColor.bg)
                        }
                    }
                    .frame(width: 30, height: 30)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekdaySymbol(for day: DayDate) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        let weekday = day.weekdayNumber   // 1=Sun...7=Sat
        return formatter.shortWeekdaySymbols[weekday - 1]
    }
}
