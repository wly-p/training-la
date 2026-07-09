import SpecPresentation
import SwiftUI
import TrainingPresentation

struct RootView: View {
    private let dependencies: AppDependencies
    @State private var exerciseListViewModel: ExerciseListViewModel
    @State private var trainingHomeViewModel: TrainingHomeViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _exerciseListViewModel = State(initialValue: dependencies.makeExerciseListViewModel())
        _trainingHomeViewModel = State(initialValue: dependencies.makeTrainingHomeViewModel())
    }

    var body: some View {
        TabView {
            TrainingHomeView(
                viewModel: trainingHomeViewModel,
                makeActiveWorkoutViewModel: dependencies.makeActiveWorkoutViewModel
            )
            .tabItem { Label("訓練", systemImage: "figure.strengthtraining.traditional") }
            ExerciseListView(viewModel: exerciseListViewModel)
                .tabItem { Label("動作庫", systemImage: "books.vertical") }
            ContentUnavailableView("歷史", systemImage: "chart.line.uptrend.xyaxis", description: Text("下一步實作"))
                .tabItem { Label("歷史", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}
