import HistoryDomain
import HistoryPresentation
import PlanData
import PlanDomain
import PlanPresentation
import SettingsPresentation
import SpecData
import SpecDomain
import SpecPresentation
import SwiftData
import TrainingData
import TrainingDomain
import TrainingPresentation

/// Composition Root：整個 App 唯一認識「具體實作」的地方。
/// 其餘所有層只依賴 protocol / use case，抽換實作（mock、加 cache、接遠端同步）只改這裡。
@MainActor
struct AppDependencies {
    let makeExerciseListViewModel: @MainActor () -> ExerciseListViewModel
    let makeTrainingHomeViewModel: @MainActor () -> TrainingHomeViewModel
    let makeActiveWorkoutViewModel: @MainActor (Workout) -> ActiveWorkoutViewModel
    let makeHistoryViewModel: @MainActor () -> HistoryViewModel
    let makePlanScheduleViewModel: @MainActor () -> PlanScheduleViewModel
    let makeSettingsViewModel: @MainActor () -> SettingsViewModel

    /// 正式組裝：SwiftData 落地儲存，各 domain 的 models 併進同一個 Schema。
    /// `inMemory`：UI 測試用，換成不落地的 store（每次啟動都是乾淨狀態）。
    static func live(inMemory: Bool = false) throws -> AppDependencies {
        let schema = Schema(
            SpecDataFactory.models + TrainingDataFactory.models + PlanDataFactory.models
        )
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
        let workoutRepository = TrainingDataFactory.makeWorkoutRepository(container: container)
        let planRepository = PlanDataFactory.makePlanWorkoutRepository(container: container)
        // 本地落實 in_use：刪動作前查 Training / Plan 有沒有引用
        let usageChecker = ExerciseUsageChecker(
            workoutRepository: workoutRepository,
            planRepository: planRepository
        )
        return assemble(
            exerciseRepository: SpecDataFactory.makeExerciseRepository(
                container: container, usageChecker: usageChecker
            ),
            workoutRepository: workoutRepository,
            planRepository: planRepository,
            // UI 測試（in-memory）用 Noop，避免真實通知權限系統彈窗干擾測試。
            restNotifications: inMemory ? NoopRestNotificationScheduler() : UserNotificationRestScheduler()
        )
    }

    /// 共用組裝邏輯：給定 repositories（真實或 mock）長出整張相依圖。
    static func assemble(
        exerciseRepository: any ExerciseRepository,
        workoutRepository: any WorkoutRepository,
        planRepository: any PlanWorkoutRepository,
        restNotifications: any RestNotificationScheduling = UserNotificationRestScheduler()
    ) -> AppDependencies {
        // Training 的 ExerciseCatalog port ← Spec 的 use case
        let catalog = SpecCatalogAdapter(listExercises: ListExercises(repository: exerciseRepository))
        // History 的讀取 port ← Training 紀錄 ＋ Spec 動作名稱
        let historyReading = HistoryReadingAdapter(
            workoutRepository: workoutRepository,
            listExercises: ListExercises(repository: exerciseRepository)
        )
        // Training ↔ Plan 的兩條 port（今天排課、標記完成）
        let plannedProvider = PlanProviderAdapter(
            todaysWorkout: TodaysWorkout(repository: planRepository),
            getPlanWorkout: { try await planRepository.get(id: $0) },
            listExercises: ListExercises(repository: exerciseRepository)
        )
        let planProgress = PlanProgressAdapter(markDone: MarkPlanWorkoutDone(repository: planRepository))
        let planCatalog = PlanCatalogAdapter(listExercises: ListExercises(repository: exerciseRepository))

        return AppDependencies(
            makeExerciseListViewModel: {
                ExerciseListViewModel(
                    listExercises: ListExercises(repository: exerciseRepository),
                    createExercise: CreateExercise(repository: exerciseRepository),
                    updateExercise: UpdateExercise(repository: exerciseRepository),
                    deleteExercise: DeleteExercise(repository: exerciseRepository)
                )
            },
            makeTrainingHomeViewModel: {
                TrainingHomeViewModel(
                    startWorkout: StartWorkout(repository: workoutRepository),
                    resumeWorkout: ResumeWorkout(repository: workoutRepository),
                    plannedProvider: plannedProvider
                )
            },
            makeActiveWorkoutViewModel: { workout in
                ActiveWorkoutViewModel(
                    workout: workout,
                    saveProgress: SaveWorkoutProgress(repository: workoutRepository),
                    finishWorkout: FinishWorkout(repository: workoutRepository, planProgress: planProgress),
                    discardWorkout: DiscardWorkout(repository: workoutRepository),
                    lastPerformance: LastPerformance(repository: workoutRepository),
                    exerciseCatalog: catalog,
                    plannedProvider: plannedProvider,
                    notifications: restNotifications
                )
            },
            makeHistoryViewModel: {
                HistoryViewModel(reading: historyReading)
            },
            makePlanScheduleViewModel: {
                PlanScheduleViewModel(
                    listPlanWorkouts: ListPlanWorkouts(repository: planRepository),
                    createPlanWorkout: CreatePlanWorkout(repository: planRepository),
                    updatePlanWorkout: UpdatePlanWorkout(repository: planRepository),
                    deletePlanWorkout: DeletePlanWorkout(repository: planRepository),
                    exerciseCatalog: planCatalog
                )
            },
            makeSettingsViewModel: {
                SettingsViewModel(store: UserDefaultsThemeStore(), iconSwitcher: UIApplicationIconSwitcher())
            }
        )
    }
}

/// Training 的 `ExerciseCatalog` port 由 Spec domain 供貨的 adapter。
private struct SpecCatalogAdapter: ExerciseCatalog {
    let listExercises: ListExercises

    func exercises() async throws -> [CatalogExercise] {
        try await listExercises(muscleGroup: nil).map {
            CatalogExercise(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup)
        }
    }
}
