import SpecPresentation
import SwiftUI

struct RootView: View {
    @State private var exerciseListViewModel: ExerciseListViewModel

    init(dependencies: AppDependencies) {
        _exerciseListViewModel = State(initialValue: dependencies.makeExerciseListViewModel())
    }

    var body: some View {
        TabView {
            ContentUnavailableView("記錄訓練", systemImage: "figure.strengthtraining.traditional", description: Text("下一步實作"))
                .tabItem { Label("訓練", systemImage: "figure.strengthtraining.traditional") }
            ExerciseListView(viewModel: exerciseListViewModel)
                .tabItem { Label("動作庫", systemImage: "books.vertical") }
            ContentUnavailableView("歷史", systemImage: "chart.line.uptrend.xyaxis", description: Text("下一步實作"))
                .tabItem { Label("歷史", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}
