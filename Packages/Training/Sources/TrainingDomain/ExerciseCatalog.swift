import Foundation
import SharedKernel

/// Training 對「動作庫」的 port：只描述自己需要什麼，不 import Spec。
/// 由 App（Composition Root）用 Spec domain 的 use case 實作接上。
public protocol ExerciseCatalog: Sendable {
    func exercises() async throws -> [CatalogExercise]
}

public struct CatalogExercise: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let muscleGroup: MuscleGroup
    /// 器材。名稱允許重複（肩推有槓鈴／啞鈴／機械三筆），選動作時就靠這個分辨，
    /// 所以 port 一定要帶過來——只有肌群的話同名動作在畫面上完全一樣。
    public let equipment: Equipment

    public init(id: UUID, name: String, muscleGroup: MuscleGroup, equipment: Equipment) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
    }
}
