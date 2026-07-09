import SwiftUI
import TrainingDomain

public struct TrainingHomeView: View {
    @Bindable private var viewModel: TrainingHomeViewModel
    private let makeActiveWorkoutViewModel: @MainActor (Workout) -> ActiveWorkoutViewModel

    public init(
        viewModel: TrainingHomeViewModel,
        makeActiveWorkoutViewModel: @escaping @MainActor (Workout) -> ActiveWorkoutViewModel
    ) {
        self.viewModel = viewModel
        self.makeActiveWorkoutViewModel = makeActiveWorkoutViewModel
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                if viewModel.resumable != nil {
                    Text("有一場訓練還沒結束")
                        .foregroundStyle(.secondary)
                    Button {
                        viewModel.resume()
                    } label: {
                        Label("繼續上次訓練", systemImage: "play.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        Task { await viewModel.startNew() }
                    } label: {
                        Label("開始訓練", systemImage: "play.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationTitle("訓練")
            .task {
                await viewModel.refresh()
            }
            .sheet(item: $viewModel.recording, onDismiss: {
                Task { await viewModel.refresh() }
            }) { workout in
                ActiveWorkoutView(viewModel: makeActiveWorkoutViewModel(workout))
                    .interactiveDismissDisabled()
            }
            .alert(
                "出錯了",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.dismissError() } }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
