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

        #expect(viewModel.errorMessage == "動作名稱不能是空白")
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

        #expect(viewModel.errorMessage == "動作名稱最長 100 字")
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

        #expect(viewModel.errorMessage == "找不到這個動作，可能已被刪除")
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
