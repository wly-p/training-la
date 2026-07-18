import SettingsPresentation
import SwiftData

/// `DataErasing` 的正式實作：清空共用 `ModelContainer` 裡所有 domain 的資料。
/// 只在 Composition Root 出現——這裡才認得全部具體的 `@Model` 型別。
struct SwiftDataEraser: DataErasing {
    let container: ModelContainer
    /// 全部要清的 model 型別（＝組 Schema 時彙總的那份）。
    let modelTypes: [any PersistentModel.Type]

    func eraseAllData() async throws {
        // 另開一個 context 做批次刪除；各 repository 的 @ModelActor context 下次 fetch 會反映空 store。
        let context = ModelContext(container)
        for type in modelTypes {
            try type.deleteAll(in: context)
        }
        try context.save()
    }
}

private extension PersistentModel {
    /// 批次刪除該型別的所有列（開放存在型別 `any PersistentModel.Type` 呼叫泛型 `delete(model:)` 的橋接）。
    static func deleteAll(in context: ModelContext) throws {
        try context.delete(model: Self.self)
    }
}
