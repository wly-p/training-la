import SpecDomain
import SwiftData

/// Composition Root（App 層）組裝相依圖時的唯一入口。
/// `ModelContainer` 由 App 層建立並在各 domain 的 Data 層之間共用；
/// schema 由各 Data 層以 `models` 貢獻，App 層彙總。
public enum SpecDataFactory {
    /// 本 package 需要納入 schema 的模型。
    public static var models: [any PersistentModel.Type] { [ExerciseModel.self] }

    public static func makeExerciseRepository(container: ModelContainer) -> any ExerciseRepository {
        SwiftDataExerciseRepository(modelContainer: container)
    }
}
