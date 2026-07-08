import SpecData
import SpecDomain
import SpecPresentation
import SwiftData

/// Composition Root：整個 App 唯一認識「具體實作」的地方。
/// 其餘所有層只依賴 protocol / use case，抽換實作（mock、加 cache、接遠端同步）只改這裡。
@MainActor
struct AppDependencies {
    let makeExerciseListViewModel: @MainActor () -> ExerciseListViewModel

    /// 正式組裝：SwiftData 落地儲存。
    /// 之後新增 domain 時，把各 Data 層的 `models` 併進同一個 Schema。
    static func live() throws -> AppDependencies {
        let container = try ModelContainer(for: Schema(SpecDataFactory.models))
        return assemble(exerciseRepository: SpecDataFactory.makeExerciseRepository(container: container))
    }

    /// 共用組裝邏輯：給定 repository（真實或 mock）長出整張相依圖。
    static func assemble(exerciseRepository: any ExerciseRepository) -> AppDependencies {
        AppDependencies(
            makeExerciseListViewModel: {
                ExerciseListViewModel(
                    listExercises: ListExercises(repository: exerciseRepository),
                    createExercise: CreateExercise(repository: exerciseRepository),
                    updateExercise: UpdateExercise(repository: exerciseRepository),
                    deleteExercise: DeleteExercise(repository: exerciseRepository)
                )
            }
        )
    }
}
