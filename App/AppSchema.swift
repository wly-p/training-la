import AbilityData
import Foundation
import PlanData
import SpecData
import SwiftData
import TrainingData

/// 全 App 的 SwiftData model 清單——**唯一的一份**。
///
/// Schema 與「清除所有資料」（`SwiftDataEraser`）都吃這裡。兩邊分開寫的話，
/// 新增一個 model 只補其中一邊，症狀會是「清資料清不乾淨」或「存進去讀不出來」，
/// 而且兩者都不會在 build 時報錯。
enum AppModels {
    static var all: [any PersistentModel.Type] {
        SpecDataFactory.models
            + TrainingDataFactory.models
            + PlanDataFactory.models
            + AbilityDataFactory.models
    }
}

/// Schema 的版本基線。
///
/// app 是 local-first、資料只存在裝置上，所以**任何一次模型變更都可能讓使用者的資料
/// 讀不出來或直接開不起來**。SwiftData 對「加 optional 欄位」「加有預設值的欄位」
/// 這類改動會自動做輕量遷移，但那是它自己判斷的——沒有 `SchemaMigrationPlan` 的話，
/// 一旦某次改動它判不了，就沒有地方可以接手。
///
/// 現在還沒上架、沒有真實使用者資料，是把基線釘下來最便宜的一刻。
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { AppModels.all }
}

/// 遷移計畫。目前只有基線，沒有 stage。
///
/// ## 之後改模型的流程（同 `ARCHITECTURE.md`「schema 版本與遷移」）
///
/// 1. 開一個新的 `AppSchemaVn`，把改動後的 model 清單放進去
/// 2. `schemas` 加上它，`stages` 加一個 `MigrationStage`
///    （純加欄位且有預設值／optional → `.lightweight`；要搬資料 → `.custom`）
/// 3. 補一支測試：舊版寫入的資料，用新版讀回來仍然完整
///
/// **不要跳過第 2 步直接改既有的 `AppSchemaV1`**——那等於謊報版本，
/// 裝了舊版的使用者升級時會拿著 V1 的資料撞上 V1 的宣告，SwiftData 不會察覺有變。
enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
