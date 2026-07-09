import Foundation
import Observation
import SharedKernel
import TrainingDomain

@MainActor
@Observable
public final class ActiveWorkoutViewModel {
    public private(set) var workout: Workout
    public private(set) var catalog: [CatalogExercise] = []
    public private(set) var lastPerformances: [UUID: [WorkoutSet]] = [:]
    public private(set) var currentExerciseId: UUID?
    public private(set) var errorMessage: String?
    /// 結束或放棄後設為 true，View 觀察到就關閉畫面。
    public private(set) var isDismissed = false

    public var draftWeightValue: Double = 20
    public var draftWeightUnit: WeightUnit = .kg
    public var draftReps: Int = 8

    private let saveProgress: SaveWorkoutProgress
    private let finishWorkout: FinishWorkout
    private let discardWorkout: DiscardWorkout
    private let lastPerformance: LastPerformance
    private let exerciseCatalog: any ExerciseCatalog

    public init(
        workout: Workout,
        saveProgress: SaveWorkoutProgress,
        finishWorkout: FinishWorkout,
        discardWorkout: DiscardWorkout,
        lastPerformance: LastPerformance,
        exerciseCatalog: any ExerciseCatalog
    ) {
        self.workout = workout
        self.saveProgress = saveProgress
        self.finishWorkout = finishWorkout
        self.discardWorkout = discardWorkout
        self.lastPerformance = lastPerformance
        self.exerciseCatalog = exerciseCatalog
    }

    // MARK: - 衍生狀態

    public var currentBlockSets: [WorkoutSet] {
        guard let id = currentExerciseId else { return [] }
        return workout.blocks.last { $0.exerciseId == id }?.sets ?? []
    }

    /// 目前動作以外、已有紀錄的區塊（畫面下方的摘要）。
    public var otherBlocks: [ExerciseBlock] {
        let currentIndex = workout.blocks.last { $0.exerciseId == currentExerciseId }?.exerciseIndex
        return workout.blocks.filter { $0.exerciseIndex != currentIndex }
    }

    public var totalSetCount: Int { workout.sets.count }

    public var durationMinutes: Int {
        guard let start = workout.startedAt else { return 0 }
        return max(0, Int(Date().timeIntervalSince(start) / 60))
    }

    public func name(for exerciseId: UUID) -> String {
        catalog.first { $0.id == exerciseId }?.name ?? "動作"
    }

    /// 「上次：60kg × 8, 8, 6」；沒有歷史回 nil。
    public func ghostText(for exerciseId: UUID) -> String? {
        guard let sets = lastPerformances[exerciseId], !sets.isEmpty else { return nil }
        return "上次：\(WeightDisplay.summary(of: sets))"
    }

    // MARK: - 動作

    public func onAppear() async {
        do {
            catalog = try await exerciseCatalog.exercises()
        } catch {
            errorMessage = "載入動作庫失敗：\(error.localizedDescription)"
        }
        // 恢復進行中場次時，回到最後一個動作
        if currentExerciseId == nil, let lastBlock = workout.blocks.last {
            await select(exerciseId: lastBlock.exerciseId)
        }
    }

    public func select(exerciseId: UUID) async {
        currentExerciseId = exerciseId
        if lastPerformances[exerciseId] == nil {
            let sets = (try? await lastPerformance(exerciseId: exerciseId, excludingWorkout: workout.id)) ?? []
            lastPerformances[exerciseId] = sets
        }
        prefillDraft()
    }

    public func completeCurrentSet() async {
        await appendSet(status: .done)
    }

    public func skipCurrentSet() async {
        await appendSet(status: .skipped)
    }

    /// 離開（未結束）。回傳 true＝可關閉畫面；空場次直接放棄刪掉。
    public func leave() async {
        if workout.sets.isEmpty {
            try? await discardWorkout(id: workout.id)
        }
        isDismissed = true
    }

    public func finish(feeling: Int?, note: String) async {
        do {
            try await finishWorkout(workout, overallFeeling: feeling, note: note)
            isDismissed = true
        } catch {
            errorMessage = "儲存失敗：\(error.localizedDescription)"
        }
    }

    public func dismissError() {
        errorMessage = nil
    }

    public func bumpWeight(_ direction: Int) {
        let step = draftWeightUnit == .kg ? 2.5 : 5.0
        draftWeightValue = max(0, draftWeightValue + step * Double(direction))
    }

    public func bumpReps(_ direction: Int) {
        draftReps = max(0, draftReps + direction)
    }

    // MARK: - 私有

    private func appendSet(status: WorkoutSetStatus) async {
        guard let exerciseId = currentExerciseId else { return }
        workout.appendSet(
            exerciseId: exerciseId,
            weight: Weight(value: draftWeightValue, unit: draftWeightUnit),
            reps: draftReps,
            status: status
        )
        do {
            try await saveProgress(workout) // 每組立即落地，中途被殺不掉資料
        } catch {
            errorMessage = "儲存失敗：\(error.localizedDescription)"
        }
    }

    /// 預填優先序：本場同動作上一組 → 上次紀錄的對應組 → 預設 20kg × 8。
    private func prefillDraft() {
        guard let exerciseId = currentExerciseId else { return }
        if let last = currentBlockSets.last {
            apply(weight: last.weight, reps: last.reps)
        } else if let history = lastPerformances[exerciseId], let first = history.first {
            apply(weight: first.weight, reps: first.reps)
        } else {
            apply(weight: Weight(value: 20, unit: .kg), reps: 8)
        }
    }

    private func apply(weight: Weight, reps: Int) {
        draftWeightValue = weight.value
        draftWeightUnit = weight.unit
        draftReps = reps
    }
}
