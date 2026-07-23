import SharedKernel
import SwiftUI
import TrainingDomain

public struct TrainingHomeView: View {
    @Bindable private var viewModel: TrainingHomeViewModel
    @Environment(\.locale) private var locale
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
                    if !viewModel.templates.isEmpty {
                        templateMenu
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

    private var templateMenu: some View {
        Menu {
            ForEach(viewModel.templates) { template in
                Button {
                    Task { await viewModel.startFromTemplate(id: template.id) }
                } label: {
                    // 範本名是使用者資料（verbatim）
                    Text(verbatim: template.name)
                }
            }
        } label: {
            Label { localText("training.startFromTemplate") } icon: { Image(systemName: "square.stack.3d.up") }
                .font(.subheadline)
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
            Text(planSummary(plan))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    /// 「臥推 3組 · 肩推 3組」／「Bench 3 sets · …」。動作名是 DB 資料；「組/sets」用
    /// `AppLanguage.localizedString` 明確解析（`String(localized:locale:)` 不會依 locale 選語言，不能用）。
    private func planSummary(_ plan: PlannedWorkoutBlueprint) -> String {
        let language = AppLanguage(locale: locale)
        return plan.exercises.map { ex in
            let format = language.localizedString("training.setCountUnit %lld", bundle: .module)
            let count = String(format: format, ex.setCount)
            return "\(ex.name) \(count)"
        }
        .joined(separator: " · ")
    }
}
