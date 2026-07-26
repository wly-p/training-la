import Foundation
import AbilityDomain
import SharedKernel
import SwiftData

@Model
final class AbilityValueModel {
    @Attribute(.unique) var exerciseId: UUID
    var value: Double
    var unitRaw: String
    var sourceRaw: String
    var updatedAt: Date

    init(exerciseId: UUID, value: Double, unitRaw: String, sourceRaw: String, updatedAt: Date) {
        self.exerciseId = exerciseId
        self.value = value
        self.unitRaw = unitRaw
        self.sourceRaw = sourceRaw
        self.updatedAt = updatedAt
    }
}

// MARK: - Mapper

extension AbilityValueModel {
    convenience init(from ability: AbilityValue) {
        self.init(
            exerciseId: ability.exerciseId,
            value: ability.value.value,
            unitRaw: ability.value.unit.rawValue,
            sourceRaw: ability.source.rawValue,
            updatedAt: ability.updatedAt
        )
    }

    func toDomain() -> AbilityValue {
        AbilityValue(
            exerciseId: exerciseId,
            value: Weight(value: value, unit: WeightUnit(rawValue: unitRaw) ?? .kg),
            source: AbilityValueSource(rawValue: sourceRaw) ?? .manual,
            updatedAt: updatedAt
        )
    }
}
