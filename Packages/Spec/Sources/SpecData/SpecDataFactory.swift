import SharedKernel
import SpecDomain
import SwiftData

/// Composition Root（App 層）組裝相依圖時的唯一入口。
/// `ModelContainer` 由 App 層建立並在各 domain 的 Data 層之間共用；
/// schema 由各 Data 層以 `models` 貢獻，App 層彙總。
public enum SpecDataFactory {
    /// 本 package 需要納入 schema 的模型。
    public static var models: [any PersistentModel.Type] { [ExerciseModel.self] }

    /// `usageChecker` 非 nil 時，包一層 decorator 在刪除前擋掉被引用的動作（丟 `inUse`）。
    ///
    /// `currentLanguage` 非 nil 時，最外層再包一層把內建動作清單合併進來。**順序不能顛倒**：
    /// 內建那層要在最外面，刪內建動作才會直接被 `readOnly` 擋掉，不會先跑去問 usageChecker。
    public static func makeExerciseRepository(
        container: ModelContainer,
        usageChecker: (any ExerciseUsageChecking)? = nil,
        currentLanguage: (@Sendable () -> AppLanguage)? = nil
    ) -> any ExerciseRepository {
        var repository: any ExerciseRepository = SwiftDataExerciseRepository(modelContainer: container)
        if let usageChecker {
            repository = UsageCheckingExerciseRepository(base: repository, usageChecker: usageChecker)
        }
        if let currentLanguage {
            repository = OfficialCatalogExerciseRepository(base: repository, currentLanguage: currentLanguage)
        }
        return repository
    }
}
