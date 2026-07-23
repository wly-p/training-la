import Foundation
import SharedKernel

/// 動作庫的一個動作（domain entity，plain struct）。
public struct Exercise: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var muscleGroup: MuscleGroup
    public var equipment: Equipment
    public var description: String?
    /// 內容來源：自建（.user）或線上公開（.official）。本地建立一律 .user。
    public var source: ContentSource
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment,
        description: String?,
        source: ContentSource = .user,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.description = description
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
