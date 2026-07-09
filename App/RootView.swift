import HistoryPresentation
import SpecPresentation
import SwiftUI
import TrainingPresentation

struct RootView: View {
    private let dependencies: AppDependencies
    @State private var exerciseListViewModel: ExerciseListViewModel
    @State private var trainingHomeViewModel: TrainingHomeViewModel
    @State private var historyViewModel: HistoryViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _exerciseListViewModel = State(initialValue: dependencies.makeExerciseListViewModel())
        _trainingHomeViewModel = State(initialValue: dependencies.makeTrainingHomeViewModel())
        _historyViewModel = State(initialValue: dependencies.makeHistoryViewModel())
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
            HistoryView(viewModel: historyViewModel)
                .tabItem { Label("歷史", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}
