import Foundation
import SharedKernel

/// 「照課表訓練」的藍圖：Training 對排課資料的需求描述。
/// Training 不認識 Plan domain——由 App 把排課轉成這個值型別餵進來。
public struct PlannedWorkoutBlueprint: Equatable, Sendable {
    public let planWorkoutId: UUID
    public let name: String?
    /// 開練前預覽（14c）頂部 kicker：循環/長期課表的週期定位，如「推拉腿 · 第 7 輪 · 第 1 天」
    /// 或「恢復期 · D 4」。由 App adapter 依課表來源組好餵進來；範本/自由訓練沒有週期定位＝nil。
    public let kicker: String?
    /// 依 (exerciseIndex, setIndex) 排序的目標佇列。
    public let targets: [PlannedTargetSet]

    public init(planWorkoutId: UUID, name: String?, kicker: String? = nil, targets: [PlannedTargetSet]) {
        self.planWorkoutId = planWorkoutId
        self.name = name
        self.kicker = kicker
        self.targets = targets
    }

    /// 依 exerciseIndex 排序的動作清單（去重，保留順序）。
    public var exercises: [(exerciseId: UUID, name: String, equipment: Equipment, setCount: Int)] {
        var order: [Int] = []
        var grouped: [Int: (UUID, String, Equipment, Int)] = [:]
        for target in targets.sorted(by: { ($0.exerciseIndex, $0.setIndex) < ($1.exerciseIndex, $1.setIndex) }) {
            if grouped[target.exerciseIndex] == nil {
                order.append(target.exerciseIndex)
                grouped[target.exerciseIndex] = (target.exerciseId, target.exerciseName, target.equipment, 0)
            }
            grouped[target.exerciseIndex]!.3 += 1
        }
        return order.map { grouped[$0]! }
    }

    /// 某動作在此藍圖裡、第 `position` 組（0-based）的目標。
    public func target(exerciseId: UUID, position: Int) -> PlannedTargetSet? {
        targets
            .filter { $0.exerciseId == exerciseId }
            .sorted { ($0.exerciseIndex, $0.setIndex) < ($1.exerciseIndex, $1.setIndex) }
            .dropFirst(position)
            .first
    }

    /// 這份排課套用的強度倍率（同一份排課的所有組共用同一個值）；1.0＝基準，UI 不顯示膠囊。
    public var intensityFactor: Double {
        targets.compactMap { $0.weightSource?.intensityFactor }.first ?? 1.0
    }
}

public struct PlannedTargetSet: Identifiable, Equatable, Sendable {
    /// 對應 plan_set 的 id（記錄時寫進 `WorkoutSet.fromPlanSetId`）。
    public let id: UUID
    public let exerciseId: UUID
    public let exerciseName: String
    /// 器材：動作名允許重複，開練前預覽要靠它分辨（跟 exerciseName 一樣是反正規化進來的顯示欄位）。
    public let equipment: Equipment
    public let exerciseIndex: Int
    public let setIndex: Int
    public let targetWeight: Weight?
    public let targetReps: Int?
    /// 這組做完的休息秒數；nil＝沒設。
    public let restSec: Int?
    /// 這個 targetWeight 數字的來源（14c 顯示算式用）；Training 不認識 Plan 的表達式型別，
    /// 由 App 層 adapter 把 Plan 的 `WeightSourceInfo` 映射成這個。
    public let weightSource: TargetWeightSource?

    public init(
        id: UUID,
        exerciseId: UUID,
        exerciseName: String,
        equipment: Equipment = .other,
        exerciseIndex: Int,
        setIndex: Int,
        targetWeight: Weight?,
        targetReps: Int?,
        restSec: Int?,
        weightSource: TargetWeightSource? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.restSec = restSec
        self.weightSource = weightSource
    }
}

/// 材料化那一刻 targetWeight 怎麼算出來的快照（14c）。跟 Plan 的 `WeightSourceInfo` 一一對應，
/// 只是換一層型別，讓 Training 不用 import PlanDomain。
public struct TargetWeightSource: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case none, absolute, relativeToLast, percentOfMax }

    public let kind: Kind
    /// `.absolute` 套用強度倍率之前的原始公斤數（14c 算式「120 kg × 75%」的 120）。
    public let base: Weight?
    public let percent: Double?
    /// `.percentOfMax` 當時查到的能力值（最大重量）；nil＝當時還沒設，算不出來。
    public let abilityValue: Weight?
    public let delta: Weight?
    /// `.relativeToLast` 當時查到的上次重量；nil＝當時沒有上次紀錄，算不出來。
    public let lastWeight: Weight?
    public let intensityFactor: Double

    public init(
        kind: Kind,
        base: Weight? = nil,
        percent: Double? = nil,
        abilityValue: Weight? = nil,
        delta: Weight? = nil,
        lastWeight: Weight? = nil,
        intensityFactor: Double
    ) {
        self.kind = kind
        self.base = base
        self.percent = percent
        self.abilityValue = abilityValue
        self.delta = delta
        self.lastWeight = lastWeight
        self.intensityFactor = intensityFactor
    }

    /// 算不出確定公斤（沒設表達式，或查無上次紀錄/能力值）。
    public var isUnresolved: Bool {
        switch kind {
        case .none: return true
        case .absolute: return false
        case .relativeToLast: return lastWeight == nil
        case .percentOfMax: return abilityValue == nil
        }
    }
}

/// 課表範本的精簡摘要（給訓練首頁「選範本開始」的清單）。
public struct PlannedTemplateSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

/// 啟用中循環課表的精簡摘要（給訓練首頁每組「今天輪到 X」的卡片）。
public struct PlannedRotationSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// 循環課表本身的名稱（區分多組並行）。
    public let rotationName: String
    /// 今天輪到的 workout 名稱。
    public let currentName: String

    public init(id: UUID, rotationName: String, currentName: String) {
        self.id = id
        self.rotationName = rotationName
        self.currentName = currentName
    }
}

/// 訓練首頁「今天休息」空狀態（13f 左）用：今天是哪份長期課表的休息日、下一個訓練日是哪天/叫什麼。
public struct RestDayInfo: Equatable, Sendable {
    public let programName: String
    /// 今天在週期裡的第幾天（1-based，＝設計稿的 `D3`）。
    public let dayNumber: Int
    /// 跑到第幾輪（1-based）；nil＝算不出／不適用，文案就不出現「第 N 輪」。
    public let roundNumber: Int?
    /// 下一個訓練日；nil＝這份套用之後都不會再有訓練日了（once 模式已經跑完週期，且往後沒有訓練日）。
    public let nextWorkoutDate: DayDate?
    public let nextWorkoutName: String?

    public init(
        programName: String,
        dayNumber: Int,
        roundNumber: Int?,
        nextWorkoutDate: DayDate?,
        nextWorkoutName: String?
    ) {
        self.programName = programName
        self.dayNumber = dayNumber
        self.roundNumber = roundNumber
        self.nextWorkoutDate = nextWorkoutDate
        self.nextWorkoutName = nextWorkoutName
    }
}

/// port：今天的排課（給訓練首頁的排課卡）＋ 依 id 找回藍圖（恢復進行中場次用）
/// ＋ 課表範本清單／依範本實例化成當日排課藍圖（「選範本開始」用）。
public protocol PlannedWorkoutProvider: Sendable {
    func todaysPlan() async throws -> PlannedWorkoutBlueprint?
    func blueprint(planWorkoutId: UUID) async throws -> PlannedWorkoutBlueprint?
    /// 可套用的課表範本清單。
    func templates() async throws -> [PlannedTemplateSummary]
    /// 依範本建立當日排課，回傳其藍圖（供直接開始訓練）。
    func instantiate(templateId: UUID) async throws -> PlannedWorkoutBlueprint?
    /// 目前啟用中、且有內容的循環課表（每組今天輪到哪張）；可多組並行。
    func activeRotations() async throws -> [PlannedRotationSummary]
    /// 開始前預覽（13d）：試算今天這組循環會是什麼樣子，不落地、不動游標。
    func previewRotation(id: UUID) async throws -> PlannedWorkoutBlueprint?
    /// 開始某組循環今天的 workout：建立當日排課、游標往下一張，回傳其藍圖。
    func startRotation(id: UUID) async throws -> PlannedWorkoutBlueprint?
    /// 今天是否剛好是某份長期課表的休息日（13f 左）；只掃長期課表，循環課表沒有休息日概念。
    func activeRestDay() async throws -> RestDayInfo?
    /// 「把明天的腿日挪到今天」（13f 左）：跟 `activeRestDay()` 同一筆套用，把今天與下一個訓練日對調。
    /// 只影響那兩天，之後的節奏照舊。
    func moveNextWorkoutToToday() async throws
}

/// port：訓練結束時回報排課進度（App 接到 Plan domain 的標記完成）。
public protocol PlanProgressRecorder: Sendable {
    func markDone(planWorkoutId: UUID) async throws
    /// 捨棄整場時清掉循環課表落地留下的孤兒排課。
    /// Plan 端只會刪 `origin == .rotation` 的——其餘來源的排課要留著讓使用者重來。
    func discardOrphanPlan(planWorkoutId: UUID) async throws
}
