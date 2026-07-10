import SpecDomain
import SwiftData

/// Composition Root（App 層）組裝相依圖時的唯一入口。
/// `ModelContainer` 由 App 層建立並在各 domain 的 Data 層之間共用；
/// schema 由各 Data 層以 `models` 貢獻，App 層彙總。
public enum SpecDataFactory {
    /// 本 package 需要納入 schema 的模型。
    public static var models: [any PersistentModel.Type] { [ExerciseModel.self] }

    /// `usageChecker` 非 nil 時，包一層 decorator 在刪除前擋掉被引用的動作（丟 `inUse`）。
    public static func makeExerciseRepository(
        container: ModelContainer,
        usageChecker: (any ExerciseUsageChecking)? = nil
    ) -> any ExerciseRepository {
        let base = SwiftDataExerciseRepository(modelContainer: container)
        guard let usageChecker else { return base }
        return UsageCheckingExerciseRepository(base: base, usageChecker: usageChecker)
    }
}
