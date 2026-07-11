import Foundation
import SharedKernel

/// 動作名稱的業務規則（對齊 API 契約：1–100 字）。
public enum ExerciseValidationError: Error, Equatable, Sendable {
    case emptyName
    case nameTooLong(max: Int)
}

private func validatedName(_ raw: String) throws -> String {
    let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw ExerciseValidationError.emptyName }
    guard name.count <= 100 else { throw ExerciseValidationError.nameTooLong(max: 100) }
    return name
}

public struct ListExercises: Sendable {
    private let repository: any ExerciseRepository

    public init(repository: any ExerciseRepository) {
        self.repository = repository
    }

    public func callAsFunction(muscleGroup: MuscleGroup? = nil) async throws -> [Exercise] {
        try await repository.list(muscleGroup: muscleGroup)
    }
}

public struct CreateExercise: Sendable {
    private let repository: any ExerciseRepository
    private let makeID: @Sendable () -> UUID
    private let now: @Sendable () -> Date

    public init(
        repository: any ExerciseRepository,
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.makeID = makeID
        self.now = now
    }

    @discardableResult
    public func callAsFunction(
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment,
        description: String?
    ) async throws -> Exercise {
        let timestamp = now()
        let exercise = Exercise(
            id: makeID(),
            name: try validatedName(name),
            muscleGroup: muscleGroup,
            equipment: equipment,
            description: description?.isEmpty == true ? nil : description,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        try await repository.create(exercise)
        return exercise
    }
}

public struct UpdateExercise: Sendable {
    private let repository: any ExerciseRepository
    private let now: @Sendable () -> Date

    public init(
        repository: any ExerciseRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.now = now
    }

    @discardableResult
    public func callAsFunction(
        id: UUID,
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment,
        description: String?
    ) async throws -> Exercise {
        guard var exercise = try await repository.get(id: id) else {
            throw ExerciseRepositoryError.notFound(id: id)
        }
        exercise.name = try validatedName(name)
        exercise.muscleGroup = muscleGroup
        exercise.equipment = equipment
        exercise.description = description?.isEmpty == true ? nil : description
        exercise.updatedAt = now()
        try await repository.update(exercise)
        return exercise
    }
}

public struct DeleteExercise: Sendable {
    private let repository: any ExerciseRepository

    public init(repository: any ExerciseRepository) {
        self.repository = repository
    }

    public func callAsFunction(id: UUID) async throws {
        try await repository.delete(id: id)
    }
}
