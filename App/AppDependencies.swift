import AbilityData
import AbilityDomain
import AbilityPresentation
import Foundation
import HistoryDomain
import HistoryPresentation
import PlanData
import PlanDomain
import PlanPresentation
import RemindersDomain
import RemindersKit
import SettingsPresentation
import SharedKernel
import SpecData
import SpecDomain
import SpecPresentation
import SwiftData
import TrainingData
import TrainingDomain
import TrainingPresentation

/// Composition Root：整個 App 唯一認識「具體實作」的地方。
/// 其餘所有層只依賴 protocol / use case，抽換實作（mock、加 cache、接遠端同步）只改這裡。
@MainActor
struct AppDependencies {
    let makeExerciseListViewModel: @MainActor () -> ExerciseListViewModel
    let makeTrainingHomeViewModel: @MainActor () -> TrainingHomeViewModel
    let makeActiveWorkoutViewModel: @MainActor (Workout) -> ActiveWorkoutViewModel
    let makeHistoryViewModel: @MainActor () -> HistoryViewModel
    let makePlanScheduleViewModel: @MainActor () -> PlanScheduleViewModel
    let makeTemplateListViewModel: @MainActor () -> TemplateListViewModel
    let makeRotationListViewModel: @MainActor () -> RotationListViewModel
    let makeRotationDetailViewModel: @MainActor (_ rotationId: UUID) -> RotationDetailViewModel
    let makeProgramListViewModel: @MainActor () -> ProgramListViewModel
    let makeProgramDetailViewModel: @MainActor (_ programId: UUID) -> ProgramDetailViewModel
    /// `onErased`：清除成功後由 App 層觸發整個畫面重建（回到全新初始狀態）。
    let makeSettingsViewModel: @MainActor (_ onErased: @escaping @MainActor () -> Void) -> SettingsViewModel
    let makeAbilityListViewModel: @MainActor () -> AbilityListViewModel
    /// DEBUG 專用：`--debug-seed=` 帶到時產生假資料（見 `DebugSeeding`）。Release build 是 no-op。
    var seedDebugDataIfRequested: @Sendable () async -> Void = {}

    /// UI 測試指定的 app 語言（`--uitest-language=en`）；沒帶或代碼不認得就回 nil。
    /// 只在 `inMemory` 模式下生效，正式啟動一律走使用者的持久化偏好。
    private static var uitestLanguageOverride: AppLanguage? {
        let prefix = "--uitest-language="
        return CommandLine.arguments
            .first { $0.hasPrefix(prefix) }
            .flatMap { AppLanguage(rawValue: String($0.dropFirst(prefix.count))) }
    }

    /// UI 測試指定的「今天」（`--uitest-today=2026-08-10`）；沒帶或格式不對就回 nil。
    /// 同樣只在 `inMemory` 模式下生效。
    ///
    /// 為什麼需要：整輪 UITest 約 16 分鐘，跑到一半跨過午夜的話，排課建在前一天、
    /// 訓練頁再查「今天」時已經是新的一天，`todaysPlan()` 變 nil、畫面掉進
    /// 「今天沒有排課」空狀態，那批「建排課再去訓練頁」的測試就整組失敗
    /// （2026-08-09 23:45 那輪的 `testUndoFromExerciseCompleteCard` 就是這樣掛的）。
    private static var uitestTodayOverride: DayDate? {
        let prefix = "--uitest-today="
        return CommandLine.arguments
            .first { $0.hasPrefix(prefix) }
            .flatMap { DayDate(isoString: String($0.dropFirst(prefix.count))) }
    }

    /// 正式組裝：SwiftData 落地儲存，各 domain 的 models 併進同一個 Schema。
    /// `inMemory`：UI 測試用，換成不落地的 store（每次啟動都是乾淨狀態）。
    static func live(inMemory: Bool = false) throws -> AppDependencies {
        let allModels = SpecDataFactory.models + TrainingDataFactory.models + PlanDataFactory.models
            + AbilityDataFactory.models
        let schema = Schema(allModels)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
        let workoutRepository = TrainingDataFactory.makeWorkoutRepository(container: container)
        let planRepository = PlanDataFactory.makePlanWorkoutRepository(container: container)
        let templateRepository = PlanDataFactory.makeWorkoutTemplateRepository(container: container)
        let rotationRepository = PlanDataFactory.makeRotationRepository(container: container)
        let programRepository = PlanDataFactory.makeProgramRepository(container: container)
        let programAssignmentRepository = PlanDataFactory.makeProgramAssignmentRepository(container: container)
        let abilityValueRepository = AbilityDataFactory.makeAbilityValueRepository(container: container)
        // 「今天」的唯一來源。正式啟動每次都重讀系統時鐘（app 一直開著也要能跨日），
        // UI 測試才用 `--uitest-today=` 釘死一天。
        let today: @Sendable () -> DayDate
        if inMemory, let fixed = uitestTodayOverride {
            today = { fixed }
        } else {
            today = { DayDate(Date()) }
        }
        // 本地落實 in_use：刪動作前查 Training / Plan / 範本 / 循環 / 長期 有沒有引用
        let usageChecker = ExerciseUsageChecker(
            workoutRepository: workoutRepository,
            planRepository: planRepository,
            templateRepository: templateRepository,
            rotationRepository: rotationRepository,
            programRepository: programRepository
        )
        // 休息提醒偏好：真實用 UserDefaults；UI 測試用記憶體。Settings 與 reminder 共用同一實例。
        let reminderStore: any RestReminderPreferenceStoring =
            inMemory ? InMemoryRestReminderPreferenceStore() : UserDefaultsRestReminderStore()
        // 語言偏好：真實落 UserDefaults；UI 測試用記憶體，並固定 seed 繁中——否則首次啟動會依
        // 模擬器系統語言決定，英文模擬器會讓中文標籤的 UITest 全崩。切換測試自己在跑時改成英文。
        //
        // `--uitest-language=<code>` 可覆蓋這個 seed。英文本地化 smoke test 需要的組合是
        // 「裝置語系繁中 ＋ app 語言英文」：兩邊都設英文的話 `String(localized:)` 也會回英文，
        // 反而把「不跟著 app 語言切」這個 bug 藏起來。
        let languageStore: any LanguagePreferenceStoring =
            inMemory ? InMemoryLanguageStore(uitestLanguageOverride ?? .zhHant) : UserDefaultsLanguageStore()
        // 預設重量單位：真實落 UserDefaults；UI 測試用記憶體（預設 kg，跟既有斷言一致）。
        // Settings 與 Training 共用同一實例——訓練頁記錄新組時要用它決定草稿單位。
        let weightUnitStore: any WeightUnitPreferenceStoring =
            inMemory ? InMemoryWeightUnitStore() : UserDefaultsWeightUnitStore()
        // 訓練偏好（重量／休息級距）：同樣 UI 測試走記憶體，用預設值（2.5kg / 30 秒），
        // 跟既有 UITest 斷言一致。Settings / Training / Plan / History 共用同一實例。
        let trainingPreferences: any TrainingPreferenceStoring =
            inMemory ? InMemoryTrainingPreferenceStore() : UserDefaultsTrainingPreferenceStore()
        // UI 測試（in-memory）用 Noop channels，避免真實通知權限彈窗／發聲干擾測試。
        let reminder: any RestEndReminding = inMemory
            ? RestEndReminder(notifications: NoopRestNotificationScheduling(),
                              sound: NoopReminderSoundPlaying(),
                              store: reminderStore)
            : RestEndReminder(notifications: UserNotificationRestScheduler(languageStore: languageStore),
                              sound: SystemSoundReminderPlayer(),
                              store: reminderStore)
        var dependencies = assemble(
            exerciseRepository: SpecDataFactory.makeExerciseRepository(
                container: container,
                usageChecker: usageChecker,
                // 內建動作清單的名稱要跟著 app 的語言設定，而 repository 拿不到 SwiftUI
                // Environment——所以讀同一個 languageStore（跟背景通知那條路一樣的做法）。
                currentLanguage: { languageStore.load() ?? .fallback }
            ),
            workoutRepository: workoutRepository,
            planRepository: planRepository,
            templateRepository: templateRepository,
            rotationRepository: rotationRepository,
            programRepository: programRepository,
            programAssignmentRepository: programAssignmentRepository,
            abilityValueRepository: abilityValueRepository,
            reminder: reminder,
            reminderStore: reminderStore,
            languageStore: languageStore,
            weightUnitStore: weightUnitStore,
            trainingPreferences: trainingPreferences,
            today: today,
            dataEraser: SwiftDataEraser(container: container, modelTypes: allModels)
        )
        #if DEBUG
        dependencies.seedDebugDataIfRequested = {
            guard let spec = DebugSeeding.requestedSpec() else { return }
            await DebugSeeding.run(spec: spec, repository: workoutRepository, today: today())
        }
        #endif
        return dependencies
    }

    /// 共用組裝邏輯：給定 repositories（真實或 mock）長出整張相依圖。
    static func assemble(
        exerciseRepository: any ExerciseRepository,
        workoutRepository: any WorkoutRepository,
        planRepository: any PlanWorkoutRepository,
        templateRepository: any WorkoutTemplateRepository,
        rotationRepository: any RotationRepository,
        programRepository: any ProgramRepository,
        programAssignmentRepository: any ProgramAssignmentRepository,
        abilityValueRepository: any AbilityValueRepository,
        reminder: any RestEndReminding,
        reminderStore: any RestReminderPreferenceStoring,
        languageStore: any LanguagePreferenceStoring = InMemoryLanguageStore(),
        weightUnitStore: any WeightUnitPreferenceStoring = InMemoryWeightUnitStore(),
        trainingPreferences: any TrainingPreferenceStoring = InMemoryTrainingPreferenceStore(),
        // 整張相依圖共用同一個「今天」——散在各處的 `= { DayDate(Date()) }` 預設值都要
        // 被這個覆蓋掉，不然 UI 測試釘死日期只會釘到其中幾個。
        today: @escaping @Sendable () -> DayDate = { DayDate(Date()) },
        dataEraser: any DataErasing = NoopDataEraser()
    ) -> AppDependencies {
        // Training 的 ExerciseCatalog port ← Spec 的 use case
        let catalog = SpecCatalogAdapter(listExercises: ListExercises(repository: exerciseRepository))
        // History 的讀取／編輯 port ← Training 紀錄 ＋ Spec 動作名稱（同一個 adapter 兼兩職）
        let historyReading = HistoryReadingAdapter(
            workoutRepository: workoutRepository,
            listExercises: ListExercises(repository: exerciseRepository),
            revertPlanWorkout: RevertPlanWorkoutDone(repository: planRepository),
            getPlanWorkout: { try await planRepository.get(id: $0) }
        )
        let planCatalog = PlanCatalogAdapter(listExercises: ListExercises(repository: exerciseRepository))
        // 重量表達式「相對上次」的投影收斂查這個（Training 的實際紀錄）。
        let lastPerformedWeightLookup = LastPerformedWeightLookupAdapter(workoutRepository: workoutRepository)
        // 重量表達式「%1RM」的投影收斂查這個（使用者的能力值）。
        let abilityValueLookup = AbilityValueLookupAdapter(
            getAbilityValue: GetAbilityValue(repository: abilityValueRepository)
        )
        // Training ↔ Plan 的兩條 port（今天排課、標記完成）
        let plannedProvider = PlanProviderAdapter(
            todaysWorkout: TodaysWorkout(repository: planRepository, today: today),
            getPlanWorkout: { try await planRepository.get(id: $0) },
            listTemplates: ListTemplates(repository: templateRepository),
            instantiateTemplate: InstantiateTemplate(
                templateRepository: templateRepository, planRepository: planRepository,
                preferences: trainingPreferences, lastPerformedWeightLookup: lastPerformedWeightLookup,
                abilityValueLookup: abilityValueLookup
            ),
            listRotations: ListRotations(repository: rotationRepository),
            previewRotationUseCase: PreviewRotationWorkout(
                rotationRepository: rotationRepository,
                preferences: trainingPreferences, lastPerformedWeightLookup: lastPerformedWeightLookup,
                abilityValueLookup: abilityValueLookup
            ),
            startRotationUseCase: StartRotation(
                rotationRepository: rotationRepository, planRepository: planRepository,
                preferences: trainingPreferences, lastPerformedWeightLookup: lastPerformedWeightLookup,
                abilityValueLookup: abilityValueLookup
            ),
            getActiveRestDay: GetActiveRestDay(
                programRepository: programRepository, assignmentRepository: programAssignmentRepository,
                today: today
            ),
            moveNextWorkout: MoveNextWorkoutToToday(
                programRepository: programRepository,
                assignmentRepository: programAssignmentRepository,
                planRepository: planRepository,
                materialize: MaterializeProjectedWorkout(
                    planRepository: planRepository,
                    preferences: trainingPreferences,
                    lastPerformedWeightLookup: lastPerformedWeightLookup,
                    abilityValueLookup: abilityValueLookup
                ),
                today: today
            ),
            today: today,
            listExercises: ListExercises(repository: exerciseRepository),
            currentLanguage: { languageStore.load() ?? .fallback }
        )
        let planProgress = PlanProgressAdapter(
            markDone: MarkPlanWorkoutDone(
                repository: planRepository,
                // 循環課表的游標在排課「完成」時才推進（E1）；沒接上這條就永遠停在第一張。
                rotationRepository: rotationRepository
            ),
            discardRotationPlan: DiscardRotationPlanWorkout(repository: planRepository)
        )

        return AppDependencies(
            makeExerciseListViewModel: {
                ExerciseListViewModel(
                    listExercises: ListExercises(repository: exerciseRepository),
                    createExercise: CreateExercise(repository: exerciseRepository),
                    updateExercise: UpdateExercise(repository: exerciseRepository),
                    deleteExercise: DeleteExercise(repository: exerciseRepository),
                    usageListing: ExerciseUsageLister(
                        templateRepository: templateRepository,
                        rotationRepository: rotationRepository,
                        programRepository: programRepository
                    )
                )
            },
            makeTrainingHomeViewModel: {
                TrainingHomeViewModel(
                    startWorkout: StartWorkout(repository: workoutRepository, today: today),
                    resumeWorkout: ResumeWorkout(repository: workoutRepository),
                    recentWorkouts: RecentWorkouts(repository: workoutRepository),
                    finishWorkout: FinishWorkout(repository: workoutRepository, planProgress: planProgress),
                    discardWorkout: DiscardWorkout(repository: workoutRepository, planProgress: planProgress),
                    plannedProvider: plannedProvider,
                    today: today
                )
            },
            makeActiveWorkoutViewModel: { workout in
                ActiveWorkoutViewModel(
                    workout: workout,
                    saveProgress: SaveWorkoutProgress(repository: workoutRepository),
                    finishWorkout: FinishWorkout(repository: workoutRepository, planProgress: planProgress),
                    discardWorkout: DiscardWorkout(repository: workoutRepository, planProgress: planProgress),
                    lastPerformance: LastPerformance(repository: workoutRepository),
                    detectPersonalRecords: DetectPersonalRecords(repository: workoutRepository),
                    exerciseCatalog: catalog,
                    plannedProvider: plannedProvider,
                    reminder: reminder,
                    weightUnitStore: weightUnitStore,
                    preferences: trainingPreferences
                )
            },
            makeHistoryViewModel: {
                HistoryViewModel(reading: historyReading, editing: historyReading, preferences: trainingPreferences)
            },
            makePlanScheduleViewModel: {
                PlanScheduleViewModel(
                    listPlanWorkouts: ListPlanWorkouts(repository: planRepository),
                    createPlanWorkout: CreatePlanWorkout(repository: planRepository),
                    updatePlanWorkout: UpdatePlanWorkout(repository: planRepository),
                    deletePlanWorkout: DeletePlanWorkout(repository: planRepository),
                    listTemplates: ListTemplates(repository: templateRepository),
                    instantiateTemplate: InstantiateTemplate(
                        templateRepository: templateRepository, planRepository: planRepository,
                        preferences: trainingPreferences, lastPerformedWeightLookup: lastPerformedWeightLookup,
                        abilityValueLookup: abilityValueLookup
                    ),
                    listPrograms: ListPrograms(repository: programRepository),
                    listAssignments: ListProgramAssignments(repository: programAssignmentRepository),
                    applyProgram: ApplyProgram(repository: programAssignmentRepository),
                    deleteAssignment: DeleteProgramAssignment(repository: programAssignmentRepository),
                    reconcile: ReconcileProgramAssignments(
                        programRepository: programRepository,
                        assignmentRepository: programAssignmentRepository,
                        planRepository: planRepository,
                        preferences: trainingPreferences,
                        lastPerformedWeightLookup: lastPerformedWeightLookup,
                        abilityValueLookup: abilityValueLookup
                    ),
                    projectSchedule: ProjectSchedule(
                        programRepository: programRepository,
                        assignmentRepository: programAssignmentRepository,
                        planRepository: planRepository
                    ),
                    materializeProjection: MaterializeProjectedWorkout(
                        planRepository: planRepository,
                        preferences: trainingPreferences,
                        lastPerformedWeightLookup: lastPerformedWeightLookup,
                        abilityValueLookup: abilityValueLookup
                    ),
                    exerciseCatalog: planCatalog,
                    preferences: trainingPreferences,
                    today: today
                )
            },
            makeTemplateListViewModel: {
                TemplateListViewModel(
                    listTemplates: ListTemplates(repository: templateRepository),
                    createTemplate: CreateTemplate(repository: templateRepository),
                    updateTemplate: UpdateTemplate(repository: templateRepository),
                    deleteTemplate: DeleteTemplate(repository: templateRepository),
                    duplicateTemplate: DuplicateTemplate(repository: templateRepository),
                    exerciseCatalog: planCatalog,
                    preferences: trainingPreferences
                )
            },
            makeRotationListViewModel: {
                RotationListViewModel(
                    listRotations: ListRotations(repository: rotationRepository),
                    createRotation: CreateRotation(repository: rotationRepository),
                    renameRotation: RenameRotation(repository: rotationRepository),
                    saveRotationWorkouts: SaveRotationWorkouts(repository: rotationRepository),
                    setRotationActive: SetRotationActive(repository: rotationRepository),
                    setRotationIntensityFactor: SetRotationIntensityFactor(repository: rotationRepository),
                    deleteRotation: DeleteRotation(repository: rotationRepository),
                    listTemplates: ListTemplates(repository: templateRepository),
                    exerciseCatalog: planCatalog,
                    preferences: trainingPreferences
                )
            },
            makeRotationDetailViewModel: { rotationId in
                RotationDetailViewModel(
                    rotationId: rotationId,
                    getRotation: GetRotation(repository: rotationRepository),
                    advanceRotation: AdvanceRotation(repository: rotationRepository),
                    resetRotation: ResetRotation(repository: rotationRepository),
                    setRotationActive: SetRotationActive(repository: rotationRepository),
                    deleteRotation: DeleteRotation(repository: rotationRepository),
                    exerciseCatalog: planCatalog
                )
            },
            makeProgramListViewModel: {
                ProgramListViewModel(
                    listPrograms: ListPrograms(repository: programRepository),
                    listAssignments: ListProgramAssignments(repository: programAssignmentRepository),
                    getProgress: GetProgramProgress(
                        programRepository: programRepository,
                        assignmentRepository: programAssignmentRepository
                    ),
                    createProgram: CreateProgram(repository: programRepository),
                    updateProgram: UpdateProgram(repository: programRepository),
                    deleteProgram: DeleteProgram(
                        programRepository: programRepository,
                        assignmentRepository: programAssignmentRepository
                    ),
                    applyProgram: ApplyProgram(repository: programAssignmentRepository),
                    listTemplates: ListTemplates(repository: templateRepository),
                    exerciseCatalog: planCatalog,
                    today: today
                )
            },
            makeProgramDetailViewModel: { programId in
                ProgramDetailViewModel(
                    programId: programId,
                    getProgram: GetProgram(repository: programRepository),
                    getProgress: GetProgramProgress(
                        programRepository: programRepository,
                        assignmentRepository: programAssignmentRepository
                    ),
                    resetProgress: ResetProgramProgress(repository: programAssignmentRepository),
                    deleteAssignment: DeleteProgramAssignment(repository: programAssignmentRepository),
                    deleteProgram: DeleteProgram(
                        programRepository: programRepository,
                        assignmentRepository: programAssignmentRepository
                    ),
                    exerciseCatalog: planCatalog,
                    today: today
                )
            },
            makeSettingsViewModel: { onErased in
                SettingsViewModel(
                    store: UserDefaultsThemeStore(),
                    iconSwitcher: UIApplicationIconSwitcher(),
                    restReminderStore: reminderStore,
                    languageStore: languageStore,
                    weightUnitStore: weightUnitStore,
                    preferences: trainingPreferences,
                    dataEraser: dataEraser,
                    onErased: onErased
                )
            },
            makeAbilityListViewModel: {
                AbilityListViewModel(
                    listAbilityValues: ListAbilityValues(repository: abilityValueRepository),
                    setAbilityValue: SetAbilityValue(repository: abilityValueRepository),
                    practicedLister: PracticedExerciseListerAdapter(
                        workoutRepository: workoutRepository,
                        listExercises: ListExercises(repository: exerciseRepository)
                    )
                )
            }
        )
    }
}

/// Training 的 `ExerciseCatalog` port 由 Spec domain 供貨的 adapter。
private struct SpecCatalogAdapter: ExerciseCatalog {
    let listExercises: ListExercises

    func exercises() async throws -> [CatalogExercise] {
        try await listExercises(muscleGroup: nil).map {
            CatalogExercise(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup, equipment: $0.equipment)
        }
    }
}
