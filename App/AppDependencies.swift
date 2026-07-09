import HistoryDomain
import HistoryPresentation
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

    /// 正式組裝：SwiftData 落地儲存，各 domain 的 models 併進同一個 Schema。
    /// `inMemory`：UI 測試用，換成不落地的 store（每次啟動都是乾淨狀態）。
    static func live(inMemory: Bool = false) throws -> AppDependencies {
        let schema = Schema(SpecDataFactory.models + TrainingDataFactory.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
        return assemble(
            exerciseRepository: SpecDataFactory.makeExerciseRepository(container: container),
            workoutRepository: TrainingDataFactory.makeWorkoutRepository(container: container)
        )
    }

    /// 共用組裝邏輯：給定 repositories（真實或 mock）長出整張相依圖。
    static func assemble(
        exerciseRepository: any ExerciseRepository,
        workoutRepository: any WorkoutRepository
    ) -> AppDependencies {
        // Training 的 ExerciseCatalog port ← Spec 的 use case（兩個 domain 互不相識，只在這裡接線）
        let catalog = SpecCatalogAdapter(listExercises: ListExercises(repository: exerciseRepository))
        // History 的讀取 port ← Training 紀錄 ＋ Spec 動作名稱
        let historyReading = HistoryReadingAdapter(
            workoutRepository: workoutRepository,
            listExercises: ListExercises(repository: exerciseRepository)
        )

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
                    resumeWorkout: ResumeWorkout(repository: workoutRepository)
                )
            },
            makeActiveWorkoutViewModel: { workout in
                ActiveWorkoutViewModel(
                    workout: workout,
                    saveProgress: SaveWorkoutProgress(repository: workoutRepository),
                    finishWorkout: FinishWorkout(repository: workoutRepository),
                    discardWorkout: DiscardWorkout(repository: workoutRepository),
                    lastPerformance: LastPerformance(repository: workoutRepository),
                    exerciseCatalog: catalog
                )
            },
            makeHistoryViewModel: {
                HistoryViewModel(reading: historyReading)
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
