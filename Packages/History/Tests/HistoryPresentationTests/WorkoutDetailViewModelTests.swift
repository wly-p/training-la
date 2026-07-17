import Foundation
import HistoryDomain
import SharedKernel
import Testing

@testable import HistoryPresentation

/// 記錄編輯／刪除呼叫的間諜 port。
private final class SpyEditing: WorkoutHistoryEditing, @unchecked Sendable {
    private(set) var deletedIds: [UUID] = []
    private(set) var lastEdits: [HistorySetEdit]?
    private(set) var lastEditWorkoutId: UUID?
    var failWith: Error?

    func deleteWorkout(id: UUID) async throws {
        if let failWith { throw failWith }
        deletedIds.append(id)
    }

    func updateSets(workoutId: UUID, edits: [HistorySetEdit]) async throws {
        if let failWith { throw failWith }
        lastEditWorkoutId = workoutId
        lastEdits = edits
    }
}

private struct AnyError: Error {}

@MainActor
struct WorkoutDetailViewModelTests {
    private let workoutId = UUID()

    private func line(id: UUID = UUID(), index: Int, weight: Double, reps: Int,
                      status: WorkoutSetStatus = .done) -> HistorySetLine {
        HistorySetLine(id: id, setIndex: index, weight: Weight(value: weight, unit: .kg),
                       reps: reps, status: status, targetWeight: nil, targetReps: nil)
    }

    private func makeDetail(_ sets: [HistorySetLine]) -> HistoryWorkoutDetail {
        HistoryWorkoutDetail(
            summary: HistoryWorkoutSummary(id: workoutId, day: DayDate(year: 2026, month: 7, day: 9),
                                           exerciseCount: 1, totalSets: sets.count,
                                           overallFeeling: nil, durationMinutes: nil),
            note: nil,
            blocks: [HistoryBlock(id: 0, exerciseName: "臥推", sets: sets)]
        )
    }

    private func makeVM(
        detail: HistoryWorkoutDetail,
        editing: SpyEditing,
        onChange: @escaping () async -> Void = {}
    ) -> WorkoutDetailViewModel {
        WorkoutDetailViewModel(
            workoutId: workoutId,
            loadDetail: { detail },
            editing: editing,
            onChange: onChange
        )
    }

    @Test func editingWeightRepsStatusSavesEdits() async {
        let setId = UUID()
        let detail = makeDetail([line(id: setId, index: 0, weight: 60, reps: 8)])
        let spy = SpyEditing()
        var changed = 0
        let vm = makeVM(detail: detail, editing: spy, onChange: { changed += 1 })
        await vm.load()

        vm.beginEditing()
        vm.bumpWeight(setId: setId, 1)          // 60 → 62.5
        vm.bumpReps(setId: setId, -1)           // 8 → 7
        vm.setStatus(setId: setId, .skipped)
        #expect(vm.hasChanges)

        await vm.save()

        #expect(vm.isEditing == false)
        #expect(spy.lastEditWorkoutId == workoutId)
        let edit = try! #require(spy.lastEdits?.first)
        #expect(edit.id == setId)
        #expect(edit.weight == Weight(value: 62.5, unit: .kg))
        #expect(edit.reps == 7)
        #expect(edit.status == .skipped)
        #expect(changed == 1) // 母清單刷新一次
    }

    @Test func hasChangesFalseWhenNothingEdited() async {
        let detail = makeDetail([line(index: 0, weight: 60, reps: 8)])
        let vm = makeVM(detail: detail, editing: SpyEditing())
        await vm.load()

        vm.beginEditing()
        #expect(vm.hasChanges == false)
    }

    @Test func cancelDiscardsDrafts() async {
        let setId = UUID()
        let detail = makeDetail([line(id: setId, index: 0, weight: 60, reps: 8)])
        let vm = makeVM(detail: detail, editing: SpyEditing())
        await vm.load()

        vm.beginEditing()
        vm.bumpReps(setId: setId, 3)
        vm.cancelEditing()

        #expect(vm.isEditing == false)
        #expect(vm.draft(for: setId) == nil)
        #expect(vm.hasChanges == false)
    }

    @Test func weightNeverGoesNegative() async {
        let setId = UUID()
        let detail = makeDetail([line(id: setId, index: 0, weight: 0, reps: 1)])
        let vm = makeVM(detail: detail, editing: SpyEditing())
        await vm.load()

        vm.beginEditing()
        vm.bumpWeight(setId: setId, -1)
        vm.bumpReps(setId: setId, -5)

        let draft = try! #require(vm.draft(for: setId))
        #expect(draft.weight.value == 0)
        #expect(draft.reps == 0)
    }

    @Test func deleteMarksDeletedAndNotifiesChange() async {
        let detail = makeDetail([line(index: 0, weight: 60, reps: 8)])
        let spy = SpyEditing()
        var changed = 0
        let vm = makeVM(detail: detail, editing: spy, onChange: { changed += 1 })
        await vm.load()

        await vm.delete()

        #expect(spy.deletedIds == [workoutId])
        #expect(vm.isDeleted)
        #expect(changed == 1)
    }

    @Test func deleteFailureSurfacesErrorAndDoesNotDismiss() async {
        let detail = makeDetail([line(index: 0, weight: 60, reps: 8)])
        let spy = SpyEditing()
        spy.failWith = AnyError()
        var changed = 0
        let vm = makeVM(detail: detail, editing: spy, onChange: { changed += 1 })
        await vm.load()

        await vm.delete()

        #expect(vm.isDeleted == false)
        #expect(vm.errorMessage != nil)
        #expect(changed == 0)
    }

    @Test func saveFailureKeepsEditingAndSurfacesError() async {
        let setId = UUID()
        let detail = makeDetail([line(id: setId, index: 0, weight: 60, reps: 8)])
        let spy = SpyEditing()
        spy.failWith = AnyError()
        let vm = makeVM(detail: detail, editing: spy)
        await vm.load()

        vm.beginEditing()
        vm.bumpReps(setId: setId, 1)
        await vm.save()

        #expect(vm.isEditing) // 失敗仍留在編輯狀態
        #expect(vm.errorMessage != nil)
    }
}
