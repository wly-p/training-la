import Foundation
import SharedKernel
import SpecDomain

/// 把 ``OfficialExerciseCatalog`` 的內建動作合併進使用者自建的動作，並擋掉對它們的寫入。
///
/// 放在 repository 這一層而不是各畫面自己合併，是因為**全 app 的動作名稱只有這一個出口**：
/// History 沒有把名稱存進紀錄、是靠 `exerciseId` 回查，Training / Plan / Ability 也都是
/// App 層 adapter 從 `ListExercises` 拿已解析的字串。在這裡做完，下游五個 package 一行都不用改。
///
/// 名稱依 `currentLanguage()` 當場解析，所以切語言即時生效——根部的 `.id(language)` 會重建畫面、
/// `.task` 重跑 → 重新讀取 → 新語言。
public struct OfficialCatalogExerciseRepository: ExerciseRepository {
    private let base: any ExerciseRepository
    private let currentLanguage: @Sendable () -> AppLanguage

    public init(base: any ExerciseRepository, currentLanguage: @escaping @Sendable () -> AppLanguage) {
        self.base = base
        self.currentLanguage = currentLanguage
    }

    public func list(muscleGroup: MuscleGroup?) async throws -> [Exercise] {
        let language = currentLanguage()
        let merged = try await base.list(muscleGroup: muscleGroup)
            + OfficialExerciseCatalog.exercises(muscleGroup: muscleGroup, language: language)
        // 底層是用 SwiftData 的 SortDescriptor(\.name) 排的，合併後就失效了；
        // 而且排序結果本來就隨語言而變，所以這裡依已解析的名稱重排。
        return merged.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func get(id: UUID) async throws -> Exercise? {
        if let stored = try await base.get(id: id) { return stored }
        return OfficialExerciseCatalog.exercise(id: id, language: currentLanguage())
    }

    /// 新建一律是使用者自建（`.user` ＋ 全新 UUID），不會撞到內建清單，原樣委派。
    public func create(_ exercise: Exercise) async throws {
        try await base.create(exercise)
    }

    public func update(_ exercise: Exercise) async throws {
        guard !OfficialExerciseCatalog.contains(id: exercise.id) else {
            throw ExerciseRepositoryError.readOnly(id: exercise.id)
        }
        try await base.update(exercise)
    }

    public func delete(id: UUID) async throws {
        guard !OfficialExerciseCatalog.contains(id: id) else {
            throw ExerciseRepositoryError.readOnly(id: id)
        }
        try await base.delete(id: id)
    }
}
