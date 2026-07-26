import DesignSystem
import Foundation
import PlanDomain
import SharedKernel

/// 課表範本包成 `PickerSheetItem`：循環加範本(12a) 用（純範本，不含「休息」）。
struct TemplatePickerItem: PickerSheetItem {
    let template: WorkoutTemplate
    let name: (UUID) -> String

    var id: UUID { template.id }
    var title: String { template.name }
    var subtitle: String { PlanFormatting.exerciseNamesSummary(sets: template.sets, name: name) }
}

/// 動作庫的動作包成 `PickerSheetItem`：範本加動作(9b) 用。
struct ExercisePickerItem: PickerSheetItem {
    let exercise: PlanCatalogExercise

    var id: UUID { exercise.id }
    var title: String { exercise.name }
    var subtitle: String { "\(exercise.equipment.displayName) · \(exercise.muscleGroup.displayName)" }
}

/// 長期指派週期格(12b) 用：範本 ＋「休息」列混在同一份清單，單選。
/// 字串在建構時就算好（呼叫端已經有 name lookup），型別本身不吃 closure。
enum DayAssignmentPickerItem: PickerSheetItem, Identifiable {
    case rest(title: String, subtitle: String)
    case template(id: UUID, title: String, subtitle: String)

    /// 固定 id 代表「休息」這個合成選項；範本用它自己的 id。
    static let restId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    var id: UUID {
        switch self {
        case .rest: Self.restId
        case .template(let id, _, _): id
        }
    }
    var title: String {
        switch self {
        case .rest(let title, _): title
        case .template(_, let title, _): title
        }
    }
    var subtitle: String {
        switch self {
        case .rest(_, let subtitle): subtitle
        case .template(_, _, let subtitle): subtitle
        }
    }

    static func template(_ template: WorkoutTemplate, name: (UUID) -> String) -> DayAssignmentPickerItem {
        .template(id: template.id, title: template.name, subtitle: PlanFormatting.exerciseNamesSummary(sets: template.sets, name: name))
    }
}
