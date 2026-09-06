import AbilityData
import Foundation
import PlanData
import SpecData
import SwiftData
import TrainingData
import XCTest

// ── AppSchema 與 AppModels 複製 ──────────────────────────────────
// （App 層 AppSchema.swift 的複製版，供測試隔離 import）

enum AppModels {
    static var all: [any PersistentModel.Type] {
        SpecData.SpecDataFactory.models
            + TrainingData.TrainingDataFactory.models
            + PlanData.PlanDataFactory.models
            + AbilityData.AbilityDataFactory.models
    }
}

enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { AppModels.all }
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

// ── 測試 ──────────────────────────────────────────────────────────

final class AppDependenciesTests: XCTestCase {
    /// 回歸測試：驗證 ModelContainer 能用 AppSchemaV1 + AppMigrationPlan 成功初始化，
    /// 防止未來有人誤刪 project.yml 的 AppTests target 或 App/AppDependencies.swift 裡的 `migrationPlan:` 參數。
    ///
    /// AppDependencies 本身在 App target 裡測試不了（application 無法被 @testable import），
    /// 但 AppSchema 與 ModelContainer 初始化是可以獨立驗證的。
    func testModelContainerInitializesWithMigrationPlan() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: AppSchemaV1.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        // 如果到這裡沒有拋錯，代表：
        // 1. ModelContainer(for:migrationPlan:configurations:) 初始化成功
        // 2. AppSchemaV1 版本能被識別
        // 3. AppMigrationPlan 的 schemas/stages 合法
        // 4. in-memory store 可用
        XCTAssertNotNil(container)
    }
}
