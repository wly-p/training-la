import Foundation
import SharedKernel
import SpecDomain

/// 在刪除前用 `ExerciseUsageChecking` port 擋掉「被引用」的動作（丟 `inUse`），
/// 其餘操作原樣委派給底層 repository。這就是架構文件預留的 decorator 位置：
/// 本地用它落實 in_use；未來走 API 時改由 API repository 把 409 對應成 `inUse`，此 decorator 不再包上去。
public struct UsageCheckingExerciseRepository: ExerciseRepository {
    private let base: any ExerciseRepository
    private let usageChecker: any ExerciseUsageChecking

    public init(base: any ExerciseRepository, usageChecker: any ExerciseUsageChecking) {
        self.base = base
        self.usageChecker = usageChecker
    }

    public func list(muscleGroup: MuscleGroup?) async throws -> [Exercise] {
        try await base.list(muscleGroup: muscleGroup)
    }

    public func get(id: UUID) async throws -> Exercise? {
        try await base.get(id: id)
    }

    public func create(_ exercise: Exercise) async throws {
        try await base.create(exercise)
    }

    public func update(_ exercise: Exercise) async throws {
        try await base.update(exercise)
    }

    public func delete(id: UUID) async throws {
        if try await usageChecker.isUsed(exerciseId: id) {
            throw ExerciseRepositoryError.inUse(id: id)
        }
        try await base.delete(id: id)
    }
}
