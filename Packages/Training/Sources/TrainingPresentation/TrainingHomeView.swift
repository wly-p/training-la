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
                    localText("training.unfinished")
                        .foregroundStyle(.secondary)
                    primaryButton("training.resume", systemImage: "play.fill") {
                        viewModel.resume()
                    }
                } else {
                    if let plan = viewModel.todaysPlan {
                        planCard(plan)
                        primaryButton("training.startFromPlan", systemImage: "play.fill") {
                            Task { await viewModel.startFromPlan() }
                        }
                        Button {
                            Task { await viewModel.startFree() }
                        } label: {
                            localText("training.free")
                        }
                        .font(.subheadline)
                    } else {
                        localText("training.noPlanToday")
                            .foregroundStyle(.secondary)
                        primaryButton("training.start", systemImage: "play.fill") {
                            Task { await viewModel.startFree() }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationTitle(localText("training.home.title"))
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
                localText("training.error"),
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.dismissError() } }
                )
            ) {
                Button(role: .cancel) {} label: { localText("training.ok") }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func primaryButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                localText(title)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.title3.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
    }

    private func planCard(_ plan: PlannedWorkoutBlueprint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                // 課表名是 DB 資料（verbatim）；沒命名時用本地化的「今日排課」
                plan.name.map { Text(verbatim: $0) } ?? localText("training.todaysPlan")
            } icon: {
                Image(systemName: "list.clipboard")
            }
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
