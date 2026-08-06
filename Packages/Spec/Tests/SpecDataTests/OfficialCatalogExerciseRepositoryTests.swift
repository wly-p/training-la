import Foundation
import SharedKernel
import SpecDomain
import Testing

@testable import SpecData

private actor SpyStore: ExerciseRepository {
    private(set) var updatedIds: [UUID] = []
    private(set) var deletedIds: [UUID] = []
    var stored: [UUID: Exercise] = [:]

    func list(muscleGroup: MuscleGroup?) async throws -> [Exercise] {
        stored.values.filter { muscleGroup == nil || $0.muscleGroup == muscleGroup }
    }
    func get(id: UUID) async throws -> Exercise? { stored[id] }
    func create(_ exercise: Exercise) async throws { stored[exercise.id] = exercise }
    func update(_ exercise: Exercise) async throws {
        updatedIds.append(exercise.id)
        stored[exercise.id] = exercise
    }
    func delete(id: UUID) async throws {
        deletedIds.append(id)
        stored[id] = nil
    }
}

struct OfficialCatalogExerciseRepositoryTests {
    private func makeRepo(
        _ base: SpyStore, language: AppLanguage = .zhHant
    ) -> OfficialCatalogExerciseRepository {
        OfficialCatalogExerciseRepository(base: base, currentLanguage: { language })
    }

    private func userExercise(name: String, muscleGroup: MuscleGroup = .chest) -> Exercise {
        Exercise(id: UUID(), name: name, muscleGroup: muscleGroup, equipment: .barbell,
                 description: nil, createdAt: Date(), updatedAt: Date())
    }

    @Test func listMergesBuiltInsWithUserExercises() async throws {
        let base = SpyStore()
        let mine = userExercise(name: "我的動作")
        try await base.create(mine)

        let listed = try await makeRepo(base).list(muscleGroup: nil)

        #expect(listed.count == OfficialExerciseCatalog.all.count + 1)
        #expect(listed.contains { $0.id == mine.id })
        #expect(listed.filter { $0.source == .official }.count == OfficialExerciseCatalog.all.count)
    }

    @Test func listIsSortedByResolvedName() async throws {
        let base = SpyStore()
        try await base.create(userExercise(name: "AAA"))
        try await base.create(userExercise(name: "ZZZ"))

        let names = try await makeRepo(base).list(muscleGroup: nil).map(\.name)

        // 底層的 SortDescriptor(\.name) 在合併後失效，要由 decorator 重排整份。
        let expected = names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        #expect(names == expected)
    }

    @Test func muscleGroupFilterAppliesToBothSources() async throws {
        let base = SpyStore()
        try await base.create(userExercise(name: "我的背部動作", muscleGroup: .back))
        try await base.create(userExercise(name: "我的胸部動作", muscleGroup: .chest))

        let listed = try await makeRepo(base).list(muscleGroup: .back)

        #expect(listed.allSatisfy { $0.muscleGroup == .back })
        #expect(listed.count == OfficialExerciseCatalog.all.filter { $0.muscleGroup == .back }.count + 1)
    }

    @Test func getFallsBackToBuiltInCatalog() async throws {
        let base = SpyStore()
        let official = try #require(OfficialExerciseCatalog.all.first)

        let found = try await makeRepo(base).get(id: official.id)

        #expect(found?.id == official.id)
        #expect(found?.source == .official)
    }

    @Test func getStillPrefersStoredExercise() async throws {
        let base = SpyStore()
        let mine = userExercise(name: "我的動作")
        try await base.create(mine)

        #expect(try await makeRepo(base).get(id: mine.id) == mine)
    }

    @Test func updateAndDeleteOnBuiltInThrowReadOnlyAndDoNotTouchBase() async throws {
        let base = SpyStore()
        let official = try #require(OfficialExerciseCatalog.all.first)
        let repo = makeRepo(base)
        let asExercise = try #require(OfficialExerciseCatalog.exercise(id: official.id, language: .zhHant))

        await #expect(throws: ExerciseRepositoryError.readOnly(id: official.id)) {
            try await repo.update(asExercise)
        }
        await #expect(throws: ExerciseRepositoryError.readOnly(id: official.id)) {
            try await repo.delete(id: official.id)
        }
        #expect(await base.updatedIds.isEmpty)
        #expect(await base.deletedIds.isEmpty)
    }

    @Test func userExercisesRemainWritable() async throws {
        let base = SpyStore()
        let repo = makeRepo(base)
        let mine = userExercise(name: "我的動作")

        try await repo.create(mine)
        try await repo.update(mine)
        try await repo.delete(id: mine.id)

        #expect(await base.updatedIds == [mine.id])
        #expect(await base.deletedIds == [mine.id])
    }

    @Test func languageIsReadOnEveryCallSoSwitchingTakesEffect() async throws {
        let base = SpyStore()
        // 語言不是建構時定死的：切語言後畫面重建、重新讀取，就該拿到另一種語言的名稱。
        // SwiftPM 不編譯 String Catalog，這裡查表兩種語言都會回 key 本身，
        // 所以只驗「closure 每次都被呼叫」，實際翻譯由 UITest 與手動驗收把關。
        let calls = Counter()
        let repo = OfficialCatalogExerciseRepository(base: base, currentLanguage: {
            calls.increment()
            return .en
        })

        _ = try await repo.list(muscleGroup: nil)
        _ = try await repo.list(muscleGroup: nil)

        #expect(calls.value == 2)
    }
}

/// `currentLanguage` closure 是 `@Sendable`，計數器得能跨 isolation 安全累加。
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock(); defer { lock.unlock() }
        count += 1
    }

    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }
}
