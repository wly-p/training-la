import DesignControls
import DesignSystem
import SwiftUI

/// `TLPickerSheet` 固定文字（取消／最近用過／全部…）：9b/12a/12b 三個情境共用同一套。
enum PlanPickerLabels {
    static let standard = TLPickerSheetLabels(
        cancel: localText("plan.cancel"),
        createNewButton: localText("picker.createNew"),
        recentSection: localText("picker.section.recent"),
        allSection: { filter in
            if let filter { localText("picker.section.allFiltered") + Text(verbatim: " · \(filter.label)") }
            else { localText("picker.section.all") }
        },
        matchCount: { count in localText("picker.matchCount \(count)") },
        createNewRow: { text in localText("picker.createNewRow \(text)") }
    )
}
