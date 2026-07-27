import Foundation
import PlanDomain
import SharedKernel
import SwiftData

@Model
final class WorkoutTemplateModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var sourceRaw: String
    var orderIndex: Int
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \TemplateSetModel.template)
    var sets: [TemplateSetModel]

    init(
        id: UUID,
        name: String,
        sourceRaw: String,
        orderIndex: Int,
        createdAt: Date,
        updatedAt: Date,
        sets: [TemplateSetModel] = []
    ) {
        self.id = id
        self.name = name
        self.sourceRaw = sourceRaw
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sets = sets
    }
}

@Model
final class TemplateSetModel {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var exerciseIndex: Int
    var setIndex: Int
    /// "absolute" ／ "relativeToLast"；nil＝沒有目標重量。見 `WeightExpressionCoding`。
    var targetWeightKindRaw: String?
    var targetWeightValue: Double?
    var targetWeightUnitRaw: String?
    var targetReps: Int?
    var restSec: Int?
    var template: WorkoutTemplateModel?

    init(
        id: UUID,
        exerciseId: UUID,
        exerciseIndex: Int,
        setIndex: Int,
        targetWeightKindRaw: String?,
        targetWeightValue: Double?,
        targetWeightUnitRaw: String?,
        targetReps: Int?,
        restSec: Int?
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.targetWeightKindRaw = targetWeightKindRaw
        self.targetWeightValue = targetWeightValue
        self.targetWeightUnitRaw = targetWeightUnitRaw
        self.targetReps = targetReps
        self.restSec = restSec
    }
}

// MARK: - Mapper

extension WorkoutTemplateModel {
    convenience init(from template: WorkoutTemplate) {
        self.init(
            id: template.id,
            name: template.name,
            sourceRaw: template.source.rawValue,
            orderIndex: template.orderIndex,
            createdAt: template.createdAt,
            updatedAt: template.updatedAt,
            sets: template.sets.map { TemplateSetModel(from: $0) }
        )
    }

    func toDomain() -> WorkoutTemplate {
        WorkoutTemplate(
            id: id,
            name: name,
            source: ContentSource(rawValue: sourceRaw) ?? .user,
            orderIndex: orderIndex,
            sets: sets
                .map { $0.toDomain() }
                .sorted { ($0.exerciseIndex, $0.setIndex) < ($1.exerciseIndex, $1.setIndex) },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension TemplateSetModel {
    convenience init(from set: PlanSet) {
        let encoded = WeightExpressionCoding.encode(set.targetWeight)
        self.init(
            id: set.id,
            exerciseId: set.exerciseId,
            exerciseIndex: set.exerciseIndex,
            setIndex: set.setIndex,
            targetWeightKindRaw: encoded.kind,
            targetWeightValue: encoded.value,
            targetWeightUnitRaw: encoded.unit,
            targetReps: set.targetReps,
            restSec: set.restSec
        )
    }

    func toDomain() -> PlanSet {
        PlanSet(
            id: id,
            exerciseId: exerciseId,
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            targetWeight: WeightExpressionCoding.decode(
                kind: targetWeightKindRaw, value: targetWeightValue, unitRaw: targetWeightUnitRaw
            ),
            targetReps: targetReps,
            restSec: restSec
        )
    }
}
