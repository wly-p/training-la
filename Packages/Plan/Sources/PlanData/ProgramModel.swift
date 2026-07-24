import Foundation
import PlanDomain
import SharedKernel
import SwiftData

@Model
final class ProgramModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var sourceRaw: String
    var orderIndex: Int
    /// 週期天數；每天內容存在攤平的 slots 裡（缺 dayIndex＝該天休息）。
    var cycleLength: Int
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \ProgramSlotModel.program)
    var slots: [ProgramSlotModel]

    init(
        id: UUID, name: String, sourceRaw: String, orderIndex: Int,
        cycleLength: Int, createdAt: Date, updatedAt: Date, slots: [ProgramSlotModel] = []
    ) {
        self.id = id
        self.name = name
        self.sourceRaw = sourceRaw
        self.orderIndex = orderIndex
        self.cycleLength = cycleLength
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.slots = slots
    }
}

/// 攤平的週期格：第 dayIndex 天排的一份 workout（copy）。
@Model
final class ProgramSlotModel {
    @Attribute(.unique) var id: UUID
    var dayIndex: Int
    var specId: UUID
    var name: String
    var program: ProgramModel?
    @Relationship(deleteRule: .cascade, inverse: \ProgramSlotSetModel.slot)
    var sets: [ProgramSlotSetModel]

    init(id: UUID, dayIndex: Int, specId: UUID, name: String, sets: [ProgramSlotSetModel] = []) {
        self.id = id
        self.dayIndex = dayIndex
        self.specId = specId
        self.name = name
        self.sets = sets
    }
}

@Model
final class ProgramSlotSetModel {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var exerciseIndex: Int
    var setIndex: Int
    var targetWeightValue: Double?
    var targetWeightUnitRaw: String?
    var targetReps: Int?
    var restSec: Int?
    var slot: ProgramSlotModel?

    init(
        id: UUID, exerciseId: UUID, exerciseIndex: Int, setIndex: Int,
        targetWeightValue: Double?, targetWeightUnitRaw: String?, targetReps: Int?, restSec: Int?
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.targetWeightValue = targetWeightValue
        self.targetWeightUnitRaw = targetWeightUnitRaw
        self.targetReps = targetReps
        self.restSec = restSec
    }
}

@Model
final class ProgramAssignmentModel {
    @Attribute(.unique) var id: UUID
    var programId: UUID
    var startDate: String        // "yyyy-MM-dd"
    var modeRaw: String
    var lastReconciledDate: String?

    init(id: UUID, programId: UUID, startDate: String, modeRaw: String, lastReconciledDate: String?) {
        self.id = id
        self.programId = programId
        self.startDate = startDate
        self.modeRaw = modeRaw
        self.lastReconciledDate = lastReconciledDate
    }
}

// MARK: - Mapper

extension ProgramModel {
    convenience init(from program: Program) {
        let slots = program.days.map { dayIndex, spec in
            ProgramSlotModel(
                id: UUID(),
                dayIndex: dayIndex,
                specId: spec.id,
                name: spec.name,
                sets: spec.sets.map { ProgramSlotSetModel(from: $0) }
            )
        }
        self.init(
            id: program.id,
            name: program.name,
            sourceRaw: program.source.rawValue,
            orderIndex: program.orderIndex,
            cycleLength: program.cycleLength,
            createdAt: program.createdAt,
            updatedAt: program.updatedAt,
            slots: slots
        )
    }

    func toDomain() -> Program {
        var days: [Int: WorkoutSpec] = [:]
        for slot in slots where (0..<max(1, cycleLength)).contains(slot.dayIndex) {
            days[slot.dayIndex] = WorkoutSpec(
                id: slot.specId,
                name: slot.name,
                sets: slot.sets
                    .map { $0.toDomain() }
                    .sorted { ($0.exerciseIndex, $0.setIndex) < ($1.exerciseIndex, $1.setIndex) }
            )
        }
        return Program(
            id: id,
            name: name,
            source: ContentSource(rawValue: sourceRaw) ?? .user,
            orderIndex: orderIndex,
            cycleLength: cycleLength,
            days: days,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension ProgramSlotSetModel {
    convenience init(from set: PlanSet) {
        self.init(
            id: set.id,
            exerciseId: set.exerciseId,
            exerciseIndex: set.exerciseIndex,
            setIndex: set.setIndex,
            targetWeightValue: set.targetWeight?.value,
            targetWeightUnitRaw: set.targetWeight?.unit.rawValue,
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
            targetWeight: targetWeightValue.map {
                Weight(value: $0, unit: WeightUnit(rawValue: targetWeightUnitRaw ?? "kg") ?? .kg)
            },
            targetReps: targetReps,
            restSec: restSec
        )
    }
}

extension ProgramAssignmentModel {
    convenience init(from assignment: ProgramAssignment) {
        self.init(
            id: assignment.id,
            programId: assignment.programId,
            startDate: assignment.startDate.isoString,
            modeRaw: assignment.mode.rawValue,
            lastReconciledDate: assignment.lastReconciledDate?.isoString
        )
    }

    func toDomain() -> ProgramAssignment {
        ProgramAssignment(
            id: id,
            programId: programId,
            startDate: DayDate(isoString: startDate) ?? DayDate(year: 1970, month: 1, day: 1),
            mode: ProgramRunMode(rawValue: modeRaw) ?? .once,
            lastReconciledDate: lastReconciledDate.flatMap { DayDate(isoString: $0) }
        )
    }
}
