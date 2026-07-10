import Foundation
import SharedKernel

/// 動作庫的一個動作（domain entity，plain struct）。
public struct Exercise: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var muscleGroup: MuscleGroup
    public var description: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        name: String,
        muscleGroup: MuscleGroup,
        description: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
