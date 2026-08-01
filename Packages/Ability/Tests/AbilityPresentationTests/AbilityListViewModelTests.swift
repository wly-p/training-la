import Foundation
import AbilityDomain
import SharedKernel
import Testing

@testable import AbilityPresentation

actor MockAbilityRepo: AbilityValueRepository {
    private var stored: [UUID: AbilityValue] = [:]
    func all() async throws -> [AbilityValue] { Array(stored.values) }
    func get(exerciseId: UUID) async throws -> AbilityValue? { stored[exerciseId] }
    func save(_ value: AbilityValue) async throws { stored[value.exerciseId] = value }
    func delete(exerciseId: UUID) async throws { stored[exerciseId] = nil }
}

struct MockPracticedLister: PracticedExerciseLister {
    let items: [PracticedExercise]
    func practicedExercises() async throws -> [PracticedExercise] { items }
}

@MainActor
private func makeViewModel(repo: MockAbilityRepo, practiced: [PracticedExercise]) -> AbilityListViewModel {
    AbilityListViewModel(
        listAbilityValues: ListAbilityValues(repository: repo),
        setAbilityValue: SetAbilityValue(repository: repo),
        practicedLister: MockPracticedLister(items: practiced)
    )
}

@MainActor
struct AbilityListViewModelTests {
    @Test func loadShowsSuggestionWhenNoCurrentValue() async throws {
        let benchId = UUID()
        let repo = MockAbilityRepo()
        let vm = makeViewModel(
            repo: repo,
            practiced: [PracticedExercise(
                exerciseId: benchId, exerciseName: "臥推", equipment: .barbell,
                maxWeight: Weight(value: 80, unit: .kg), lastWeight: Weight(value: 80, unit: .kg), lastReps: 8,
                lastPerformedOn: DayDate(year: 2026, month: 8, day: 1)
            )]
        )

        await vm.load()

        #expect(vm.rows.count == 1)
        #expect(vm.rows.first?.current == nil)
        #expect(vm.rows.first?.suggestion != nil)   // 建議值＝歷來最大重量 80kg
    }

    @Test func loadHidesSuggestionWhenItMatchesCurrentValue() async throws {
        let benchId = UUID()
        let repo = MockAbilityRepo()
        // 先手動設一個剛好等於建議值的能力值，避免一直被提示更新同一個數字。
        let suggested = SuggestAbilityValue()(maxWeight: Weight(value: 80, unit: .kg))
        try await repo.save(AbilityValue(exerciseId: benchId, value: suggested))
        let vm = makeViewModel(
            repo: repo,
            practiced: [PracticedExercise(
                exerciseId: benchId, exerciseName: "臥推", equipment: .barbell,
                maxWeight: Weight(value: 80, unit: .kg), lastWeight: Weight(value: 80, unit: .kg), lastReps: 8,
                lastPerformedOn: DayDate(year: 2026, month: 8, day: 1)
            )]
        )

        await vm.load()

        #expect(vm.rows.first?.suggestion == nil)
    }

    @Test func setValuePersistsAsManualAndReloads() async throws {
        let benchId = UUID()
        let repo = MockAbilityRepo()
        let vm = makeViewModel(
            repo: repo,
            practiced: [PracticedExercise(
                exerciseId: benchId, exerciseName: "臥推", equipment: .barbell,
                maxWeight: Weight(value: 80, unit: .kg), lastWeight: Weight(value: 80, unit: .kg), lastReps: 8,
                lastPerformedOn: DayDate(year: 2026, month: 8, day: 1)
            )]
        )
        await vm.load()

        await vm.setValue(exerciseId: benchId, value: Weight(value: 100, unit: .kg))

        #expect(vm.rows.first?.current?.value == Weight(value: 100, unit: .kg))
        #expect(vm.rows.first?.current?.source == .manual)
    }

    @Test func acceptSuggestionPersistsAsEstimated() async throws {
        let benchId = UUID()
        let repo = MockAbilityRepo()
        let vm = makeViewModel(
            repo: repo,
            practiced: [PracticedExercise(
                exerciseId: benchId, exerciseName: "臥推", equipment: .barbell,
                maxWeight: Weight(value: 80, unit: .kg), lastWeight: Weight(value: 80, unit: .kg), lastReps: 8,
                lastPerformedOn: DayDate(year: 2026, month: 8, day: 1)
            )]
        )
        await vm.load()
        let row = vm.rows[0]

        await vm.acceptSuggestion(row)

        #expect(vm.rows.first?.current?.source == .estimated)
        #expect(vm.rows.first?.suggestion == nil)   // 接受後跟目前值一致，不再提示
    }

    @Test func rowsSortedByExerciseName() async throws {
        let repo = MockAbilityRepo()
        let vm = makeViewModel(
            repo: repo,
            practiced: [
                PracticedExercise(
                    exerciseId: UUID(), exerciseName: "Squat", equipment: .barbell,
                    maxWeight: Weight(value: 100, unit: .kg), lastWeight: Weight(value: 100, unit: .kg), lastReps: 5,
                    lastPerformedOn: DayDate(year: 2026, month: 8, day: 1)
                ),
                PracticedExercise(
                    exerciseId: UUID(), exerciseName: "Bench", equipment: .barbell,
                    maxWeight: Weight(value: 80, unit: .kg), lastWeight: Weight(value: 80, unit: .kg), lastReps: 8,
                    lastPerformedOn: DayDate(year: 2026, month: 8, day: 1)
                ),
            ]
        )

        await vm.load()

        #expect(vm.rows.map(\.exerciseName) == ["Bench", "Squat"])
    }

    // MARK: - 排序／搜尋／篩選（handoff-15 F 節）

    private func practiced(
        _ name: String, _ equipment: Equipment, day: Int, id: UUID = UUID()
    ) -> PracticedExercise {
        PracticedExercise(
            exerciseId: id, exerciseName: name, equipment: equipment,
            maxWeight: Weight(value: 100, unit: .kg),
            lastWeight: Weight(value: 100, unit: .kg), lastReps: 5,
            lastPerformedOn: DayDate(year: 2026, month: 8, day: day)
        )
    }

    /// 已設定的排前面：這頁最高頻的任務是把沒設定的補完，但已設定的是「查閱」對象，
    /// 兩者混在一起會讓人找不到剛設好的值。
    @Test func setRowsSortBeforeUnsetRows() async throws {
        let setId = UUID()
        let repo = MockAbilityRepo()
        try await repo.save(AbilityValue(exerciseId: setId, value: Weight(value: 100, unit: .kg)))
        let vm = makeViewModel(repo: repo, practiced: [
            practiced("未設定的", .barbell, day: 1),
            practiced("已設定的", .barbell, day: 1, id: setId),
        ])

        await vm.load()

        #expect(vm.rows.map(\.exerciseName) == ["已設定的", "未設定的"])
    }

    /// 未設定的按最近訓練日期排（近的在前）——剛練完的最該被提醒去設。
    @Test func unsetRowsSortByMostRecentTrainingDay() async throws {
        let vm = makeViewModel(repo: MockAbilityRepo(), practiced: [
            practiced("很久以前", .barbell, day: 1),
            practiced("昨天練的", .barbell, day: 20),
        ])

        await vm.load()

        #expect(vm.rows.map(\.exerciseName) == ["昨天練的", "很久以前"])
    }

    /// 搜尋要比對器材名：打「啞鈴」要撈出全部啞鈴動作，而不是只比對動作名。
    @Test func searchMatchesEquipmentName() async throws {
        let vm = makeViewModel(repo: MockAbilityRepo(), practiced: [
            practiced("臥推", .barbell, day: 1),
            practiced("肩推", .dumbbell, day: 1),
        ])
        await vm.load()

        // 查詢字串取自同一支 `displayName(_:)`，而不是寫死「啞鈴」：SwiftPM 不編譯 String Catalog，
        // 在單元測試裡查表會回 key 本身，寫死中文的話這條就永遠比不中。這樣寫在兩種環境都成立，
        // 測的也是真正的行為——搜尋要能用「當前語言的器材名」撈到動作。
        let locale = Locale(identifier: "zh-Hant")
        vm.searchText = Equipment.dumbbell.displayName(locale)

        #expect(vm.visibleRows(locale: locale).map(\.exerciseName) == ["肩推"])
    }

    @Test func searchMatchesExerciseName() async throws {
        let vm = makeViewModel(repo: MockAbilityRepo(), practiced: [
            practiced("臥推", .barbell, day: 1),
            practiced("深蹲", .barbell, day: 1),
        ])
        await vm.load()

        vm.searchText = "深蹲"

        #expect(vm.visibleRows(locale: Locale(identifier: "zh-Hant")).map(\.exerciseName) == ["深蹲"])
    }

    @Test func unsetFilterShowsOnlyRowsWithoutValue() async throws {
        let setId = UUID()
        let repo = MockAbilityRepo()
        try await repo.save(AbilityValue(exerciseId: setId, value: Weight(value: 100, unit: .kg)))
        let vm = makeViewModel(repo: repo, practiced: [
            practiced("已設定的", .barbell, day: 1, id: setId),
            practiced("未設定的", .barbell, day: 1),
        ])
        await vm.load()

        vm.filter = .unset

        #expect(vm.visibleRows(locale: Locale(identifier: "zh-Hant")).map(\.exerciseName) == ["未設定的"])
        #expect(vm.unsetCount == 1)
        #expect(vm.setCount == 1)
    }

    @Test func equipmentFilterNarrowsToThatEquipment() async throws {
        let vm = makeViewModel(repo: MockAbilityRepo(), practiced: [
            practiced("臥推", .barbell, day: 1),
            practiced("肩推", .dumbbell, day: 1),
        ])
        await vm.load()

        vm.filter = .equipment(.dumbbell)

        #expect(vm.visibleRows(locale: Locale(identifier: "zh-Hant")).map(\.exerciseName) == ["肩推"])
    }

    /// 沒有任何動作的器材 chip 要停用（View 降到 45% opacity）。
    @Test func hasExercisesReportsEmptyEquipment() async throws {
        let vm = makeViewModel(repo: MockAbilityRepo(), practiced: [practiced("臥推", .barbell, day: 1)])
        await vm.load()

        #expect(vm.hasExercises(for: .barbell))
        #expect(!vm.hasExercises(for: .kettlebell))
    }

    /// 啞鈴的重量是每邊，清單與編輯頁都要標，否則 20kg 會被誤讀成總重。
    @Test func dumbbellRowsAreMarkedPerSide() async throws {
        let vm = makeViewModel(repo: MockAbilityRepo(), practiced: [
            practiced("肩推", .dumbbell, day: 1),
            practiced("臥推", .barbell, day: 1),
        ])
        await vm.load()

        #expect(vm.rows.first { $0.exerciseName == "肩推" }?.isPerSide == true)
        #expect(vm.rows.first { $0.exerciseName == "臥推" }?.isPerSide == false)
    }

}
