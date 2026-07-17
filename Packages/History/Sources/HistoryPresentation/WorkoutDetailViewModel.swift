import Foundation
import HistoryDomain
import Observation
import SharedKernel

/// 單場詳情頁的狀態機：讀取詳情、編輯各組（重量／次數／狀態）、儲存或刪除整場。
/// 儲存／刪除成功後透過 `onChange` 通知母清單刷新，讓「按日期／按動作」兩種查詢一致更新。
@MainActor
@Observable
public final class WorkoutDetailViewModel {
    public private(set) var detail: HistoryWorkoutDetail?
    public private(set) var isEditing = false
    /// 刪除完成 → View 觀察到就關閉詳情頁。
    public private(set) var isDeleted = false
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    /// 編輯中的各組草稿（key = set id）；進入編輯時由 detail 快照而來。
    public private(set) var drafts: [UUID: SetDraft] = [:]

    private let workoutId: UUID
    private let loadDetail: () async -> HistoryWorkoutDetail?
    private let editing: any WorkoutHistoryEditing
    private let onChange: () async -> Void

    public init(
        workoutId: UUID,
        loadDetail: @escaping () async -> HistoryWorkoutDetail?,
        editing: any WorkoutHistoryEditing,
        onChange: @escaping () async -> Void
    ) {
        self.workoutId = workoutId
        self.loadDetail = loadDetail
        self.editing = editing
        self.onChange = onChange
    }

    /// 場次內全部組（跨動作區塊攤平，供編輯逐組取用）。
    private var allLines: [HistorySetLine] {
        detail?.blocks.flatMap { $0.sets } ?? []
    }

    public func load() async {
        detail = await loadDetail()
    }

    // MARK: - 編輯

    public func beginEditing() {
        drafts = Dictionary(uniqueKeysWithValues: allLines.map {
            ($0.id, SetDraft(weight: $0.weight, reps: $0.reps, status: $0.status))
        })
        isEditing = true
    }

    public func cancelEditing() {
        isEditing = false
        drafts = [:]
    }

    public func draft(for setId: UUID) -> SetDraft? { drafts[setId] }

    /// 調整某組重量（kg ±2.5／lb ±5，對齊記錄畫面的級距），不小於 0。
    public func bumpWeight(setId: UUID, _ direction: Int) {
        guard var draft = drafts[setId] else { return }
        let step = draft.weight.unit == .kg ? 2.5 : 5.0
        draft.weight.value = max(0, draft.weight.value + step * Double(direction))
        drafts[setId] = draft
    }

    public func bumpReps(setId: UUID, _ direction: Int) {
        guard var draft = drafts[setId] else { return }
        draft.reps = max(0, draft.reps + direction)
        drafts[setId] = draft
    }

    public func setStatus(setId: UUID, _ status: WorkoutSetStatus) {
        guard var draft = drafts[setId] else { return }
        draft.status = status
        drafts[setId] = draft
    }

    /// 是否有實際改動（沒改就不必打儲存）。
    public var hasChanges: Bool {
        allLines.contains { line in
            guard let draft = drafts[line.id] else { return false }
            return draft.weight != line.weight || draft.reps != line.reps || draft.status != line.status
        }
    }

    public func save() async {
        guard isEditing else { return }
        let edits = allLines.compactMap { line -> HistorySetEdit? in
            guard let draft = drafts[line.id] else { return nil }
            return HistorySetEdit(id: line.id, weight: draft.weight, reps: draft.reps, status: draft.status)
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await editing.updateSets(workoutId: workoutId, edits: edits)
            isEditing = false
            drafts = [:]
            detail = await loadDetail() // 重讀本頁
            await onChange()            // 刷新母清單（按日期／按動作）
        } catch {
            errorMessage = "儲存失敗：\(error.localizedDescription)"
        }
    }

    // MARK: - 刪除

    public func delete() async {
        do {
            try await editing.deleteWorkout(id: workoutId)
            isDeleted = true
            await onChange()
        } catch {
            errorMessage = "刪除失敗：\(error.localizedDescription)"
        }
    }

    public func dismissError() { errorMessage = nil }
}

/// 編輯中一組的草稿值。
public struct SetDraft: Equatable, Sendable {
    public var weight: Weight
    public var reps: Int
    public var status: WorkoutSetStatus

    public init(weight: Weight, reps: Int, status: WorkoutSetStatus) {
        self.weight = weight
        self.reps = reps
        self.status = status
    }
}
