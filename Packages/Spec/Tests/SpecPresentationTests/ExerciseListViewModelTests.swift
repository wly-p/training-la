import Foundation
import SharedKernel
import SpecDomain
import Testing

@testable import SpecPresentation

@MainActor
struct ExerciseListViewModelTests {
    private func makeViewModel(repository: MockExerciseRepository) -> ExerciseListViewModel {
        ExerciseListViewModel(
            listExercises: ListExercises(repository: repository),
            createExercise: CreateExercise(repository: repository),
            updateExercise: UpdateExercise(repository: repository),
            deleteExercise: DeleteExercise(repository: repository)
        )
    }

    @Test func loadPopulatesExercisesSortedByRepository() async {
        let repo = MockExerciseRepository()
        await repo.seed([.stub(name: "深蹲", muscleGroup: .legs), .stub(name: "臥推", muscleGroup: .chest)])
        let viewModel = makeViewModel(repository: repo)

        await viewModel.load()

        #expect(viewModel.exercises.map(\.name) == ["深蹲", "臥推"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test func setFilterReloadsWithMuscleGroup() async {
        let repo = MockExerciseRepository()
        await repo.seed([.stub(name: "深蹲", muscleGroup: .legs), .stub(name: "臥推", muscleGroup: .chest)])
        let viewModel = makeViewModel(repository: repo)

        await viewModel.setFilter(.legs)

        #expect(viewModel.filter == .legs)
        #expect(viewModel.exercises.map(\.name) == ["深蹲"])
    }

    @Test func visibleExercisesFiltersBySearchText() async {
        let repo = MockExerciseRepository()
        await repo.seed([.stub(name: "深蹲"), .stub(name: "臥推")])
        let viewModel = makeViewModel(repository: repo)
        await viewModel.load()

        viewModel.searchText = "臥"

        #expect(viewModel.visibleExercises.map(\.name) == ["臥推"])
    }

    @Test func visibleExercisesReturnsAllWhenSearchTextEmpty() async {
        let repo = MockExerciseRepository()
        await repo.seed([.stub(name: "深蹲"), .stub(name: "臥推")])
        let viewModel = makeViewModel(repository: repo)
        await viewModel.load()

        #expect(viewModel.visibleExercises.count == 2)
    }

    @Test func addCreatesExerciseAndReloadsList() async {
        let repo = MockExerciseRepository()
        let viewModel = makeViewModel(repository: repo)

        await viewModel.add(name: "硬舉", muscleGroup: .back, equipment: .barbell, description: nil)

        #expect(viewModel.exercises.map(\.name) == ["硬舉"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test func addWithEmptyNameSetsErrorMessageAndDoesNotAdd() async {
        let repo = MockExerciseRepository()
        let viewModel = makeViewModel(repository: repo)

        await viewModel.add(name: "   ", muscleGroup: .back, equipment: .barbell, description: nil)

        #expect(viewModel.errorMessage?.key == "spec.error.nameBlank")
        #expect(viewModel.exercises.isEmpty)
    }

    @Test func addWithOverlongNameSetsErrorMessage() async {
        let repo = MockExerciseRepository()
        let viewModel = makeViewModel(repository: repo)

        await viewModel.add(
            name: String(repeating: "推", count: 101),
            muscleGroup: .chest,
            equipment: .barbell,
            description: nil
        )

        #expect(viewModel.errorMessage?.key == "spec.error.nameTooLong %lld")
    }

    @Test func editUpdatesExerciseAndReloadsList() async {
        let repo = MockExerciseRepository()
        let original = Exercise.stub(name: "臥推", muscleGroup: .chest)
        await repo.seed([original])
        let viewModel = makeViewModel(repository: repo)
        await viewModel.load()

        await viewModel.edit(id: original.id, name: "上斜臥推", muscleGroup: .chest, equipment: .dumbbell, description: "30度")

        #expect(viewModel.exercises.first?.name == "上斜臥推")
        #expect(viewModel.exercises.first?.equipment == .dumbbell)
    }

    @Test func editMissingExerciseSetsNotFoundErrorMessage() async {
        let repo = MockExerciseRepository()
        let viewModel = makeViewModel(repository: repo)

        await viewModel.edit(id: UUID(), name: "硬舉", muscleGroup: .back, equipment: .barbell, description: nil)

        #expect(viewModel.errorMessage?.key == "spec.error.notFound")
    }

    @Test func removeDeletesExerciseAndReloadsList() async {
        let repo = MockExerciseRepository()
        let exercise = Exercise.stub()
        await repo.seed([exercise])
        let viewModel = makeViewModel(repository: repo)
        await viewModel.load()

        await viewModel.remove(id: exercise.id)

        #expect(viewModel.exercises.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func dismissErrorClearsErrorMessage() async {
        let repo = MockExerciseRepository()
        let viewModel = makeViewModel(repository: repo)
        await viewModel.add(name: "", muscleGroup: .chest, equipment: .barbell, description: nil)
        #expect(viewModel.errorMessage != nil)

        viewModel.dismissError()

        #expect(viewModel.errorMessage == nil)
    }
}

/// 動作庫「常用」分組的排序來源。
///
/// 舊的佔位邏輯是「取清單前 8 筆」，內建動作庫上線後清單常駐 80 筆，
/// 等於固定顯示 8 個使用者從沒碰過的內建動作。這幾支釘的是「只列練過的、依次數排」。
@MainActor
struct FrequentExercisesTests {
    /// 可注入固定次數的假來源；`nil` 代表 App 沒接線（預覽／未 wire 的測試）。
    private struct StubUsageCounting: ExerciseUsageCounting {
        let counts: [UUID: Int]
        func usageCounts() async throws -> [UUID: Int] { counts }
    }

    private struct FailingUsageCounting: ExerciseUsageCounting {
        struct Boom: Error {}
        func usageCounts() async throws -> [UUID: Int] { throw Boom() }
    }

    private func makeViewModel(
        repository: MockExerciseRepository, counting: (any ExerciseUsageCounting)? = nil
    ) -> ExerciseListViewModel {
        ExerciseListViewModel(
            listExercises: ListExercises(repository: repository),
            createExercise: CreateExercise(repository: repository),
            updateExercise: UpdateExercise(repository: repository),
            deleteExercise: DeleteExercise(repository: repository),
            usageCounting: counting
        )
    }

    @Test func frequentIsOrderedByUsageCountDescending() async {
        let repo = MockExerciseRepository()
        let squat = Exercise.stub(name: "深蹲", muscleGroup: .legs)
        let bench = Exercise.stub(name: "臥推", muscleGroup: .chest)
        let row = Exercise.stub(name: "划船", muscleGroup: .back)
        await repo.seed([squat, bench, row])
        let viewModel = makeViewModel(
            repository: repo,
            counting: StubUsageCounting(counts: [squat.id: 3, bench.id: 12, row.id: 7])
        )

        await viewModel.load()

        #expect(viewModel.frequentExercises.map(\.name) == ["臥推", "划船", "深蹲"])
    }

    /// 沒練過的動作不該出現在「常用」——這正是舊佔位邏輯壞掉的地方。
    @Test func frequentExcludesExercisesNeverPerformed() async {
        let repo = MockExerciseRepository()
        let squat = Exercise.stub(name: "深蹲", muscleGroup: .legs)
        let neverDone = Exercise.stub(name: "沒練過的內建動作", muscleGroup: .chest)
        await repo.seed([squat, neverDone])
        let viewModel = makeViewModel(repository: repo, counting: StubUsageCounting(counts: [squat.id: 1]))

        await viewModel.load()

        #expect(viewModel.frequentExercises.map(\.name) == ["深蹲"])
    }

    @Test func frequentIsEmptyWhenNothingHasBeenPerformed() async {
        let repo = MockExerciseRepository()
        await repo.seed([.stub(name: "深蹲", muscleGroup: .legs), .stub(name: "臥推", muscleGroup: .chest)])
        let viewModel = makeViewModel(repository: repo, counting: StubUsageCounting(counts: [:]))

        await viewModel.load()

        #expect(viewModel.frequentExercises.isEmpty)
    }

    /// 同次數時用名稱排序，否則輸出會跟著 Dictionary 的走訪順序跳動。
    @Test func equalCountsFallBackToNameOrderSoOutputIsStable() async {
        let repo = MockExerciseRepository()
        let a = Exercise.stub(name: "Bench", muscleGroup: .chest)
        let b = Exercise.stub(name: "Alpha", muscleGroup: .back)
        await repo.seed([a, b])
        let viewModel = makeViewModel(repository: repo, counting: StubUsageCounting(counts: [a.id: 5, b.id: 5]))

        await viewModel.load()

        #expect(viewModel.frequentExercises.map(\.name) == ["Alpha", "Bench"])
    }

    /// 搜尋中時「常用」也要跟著過濾（兩者都是純前端呈現，不該互相打架）。
    @Test func frequentRespectsTheSearchText() async {
        let repo = MockExerciseRepository()
        let squat = Exercise.stub(name: "深蹲", muscleGroup: .legs)
        let bench = Exercise.stub(name: "臥推", muscleGroup: .chest)
        await repo.seed([squat, bench])
        let viewModel = makeViewModel(repository: repo, counting: StubUsageCounting(counts: [squat.id: 3, bench.id: 9]))
        await viewModel.load()

        viewModel.searchText = "深蹲"

        #expect(viewModel.frequentExercises.map(\.name) == ["深蹲"])
    }

    /// 次數查詢炸掉不該讓整個動作庫顯示錯誤——最差就是「常用」空著。
    @Test func failingUsageLookupLeavesTheLibraryUsable() async {
        let repo = MockExerciseRepository()
        await repo.seed([.stub(name: "深蹲", muscleGroup: .legs)])
        let viewModel = makeViewModel(repository: repo, counting: FailingUsageCounting())

        await viewModel.load()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.exercises.count == 1)
        #expect(viewModel.frequentExercises.isEmpty)
    }

    /// App 沒接線（nil）時等同沒有資料，不該 crash 也不該亂猜。
    @Test func withoutAnyUsageSourceFrequentIsEmpty() async {
        let repo = MockExerciseRepository()
        await repo.seed([.stub(name: "深蹲", muscleGroup: .legs)])
        let viewModel = makeViewModel(repository: repo)

        await viewModel.load()

        #expect(viewModel.frequentExercises.isEmpty)
    }
}
