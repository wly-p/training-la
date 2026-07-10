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
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)

                if viewModel.resumable != nil {
                    Text("有一場訓練還沒結束")
                        .foregroundStyle(.secondary)
                    primaryButton("繼續上次訓練", systemImage: "play.fill") {
                        viewModel.resume()
                    }
                } else {
                    if let plan = viewModel.todaysPlan {
                        planCard(plan)
                        primaryButton("照課表開始", systemImage: "play.fill") {
                            Task { await viewModel.startFromPlan() }
                        }
                        Button("自由訓練") {
                            Task { await viewModel.startFree() }
                        }
                        .font(.subheadline)
                    } else {
                        Text("今天沒有排課")
                            .foregroundStyle(.secondary)
                        primaryButton("開始訓練", systemImage: "play.fill") {
                            Task { await viewModel.startFree() }
                        }
                    }
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

    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
    }

    private func planCard(_ plan: PlannedWorkoutBlueprint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(plan.name ?? "今日排課", systemImage: "list.clipboard")
                .font(.headline)
            Text(plan.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}
