import DesignSystem
import SharedKernel
import SpecDomain
import SwiftUI

public struct ExerciseListView: View {
    /// 目前語言：肌群／器材的顯示名要靠它才會跟著 app 設定走（而非手機語系）。
    @Environment(\.locale) private var locale
    @Bindable private var viewModel: ExerciseListViewModel
    @State private var editingTarget: FormTarget?
    /// 分組方式（純前端呈現，不動 VM 的 `filter`）。
    @State private var grouping: Grouping = .muscle
    /// 由動作庫殼頁首「+」轉發：值一變就開建立表單（見 App/RootView 的 LibraryTabView）。
    private let createToken: Int

    public init(viewModel: ExerciseListViewModel, createToken: Int = 0) {
        self.viewModel = viewModel
        self.createToken = createToken
    }

    private enum Grouping: Hashable { case muscle, equipment, frequent, all }

    // 不自帶 NavigationStack：嵌在動作庫 tab 共用的 NavigationStack 內（見 App/RootView 的 LibraryTabView）。
    public var body: some View {
        VStack(spacing: 0) {
            TLSearchField(text: $viewModel.searchText,
                           placeholder: localText("spec.searchExercises"),
                           identifier: "exerciseList.search")
                .padding(.horizontal, TLSpace.page)
                .padding(.bottom, TLSpace.gapM)

            TLSegmentedControl(selection: $grouping, options: [
                .init(.muscle, localText("spec.muscleGroup")),
                .init(.equipment, localText("spec.equipment")),
                .init(.frequent, localText("spec.group.frequent")),
                .init(.all, localText("spec.all")),
            ], identifierPrefix: "exerciseList.group")
            .padding(.horizontal, TLSpace.page)
            .padding(.bottom, TLSpace.gapM)

            ScrollView {
                // 用 sections 而不是 visibleExercises 判斷：「常用」可能是空的
                // （一場都沒練過）而動作庫本身有 80 筆內建動作，那時不該只留一片空白。
                if sections.isEmpty {
                    emptyState
                        .padding(.horizontal, TLSpace.page)
                        .padding(.top, TLSpace.gapL)
                } else {
                    LazyVStack(alignment: .leading, spacing: TLSpace.section) {
                        ForEach(sections, id: \.id) { section in
                            VStack(alignment: .leading, spacing: 0) {
                                if let header = section.header {
                                    TLSectionHeader(header)
                                }
                                TLGroup {
                                    ForEach(section.exercises) { exercise in
                                        row(for: exercise)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, TLSpace.page)
                    .padding(.top, TLSpace.gapS)
                    .padding(.bottom, TLSpace.pageBottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TLColor.bg)
        .task { await viewModel.load() }
        .onChange(of: createToken) { editingTarget = .create }
        .sheet(item: $editingTarget) { target in
            ExerciseFormView(
                target: target,
                loadUsages: { await viewModel.usages(of: $0) },
                onSubmit: { name, muscleGroup, equipment, description in
                    switch target {
                    case .create:
                        await viewModel.add(name: name, muscleGroup: muscleGroup, equipment: equipment, description: description)
                    case .edit(let exercise):
                        await viewModel.edit(id: exercise.id, name: name, muscleGroup: muscleGroup, equipment: equipment, description: description)
                    }
                },
                onDelete: {
                    if case .edit(let exercise) = target {
                        await viewModel.remove(id: exercise.id)
                    }
                }
            )
        }
        .alert(
            localText("spec.error"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button(role: .cancel) {} label: { localText("spec.ok") }
                .accessibilityIdentifier("exerciseList.error.ok")
        } message: {
            // `?? ""` 會讓那個空字串變成可翻譯字面量，被抽進 String Catalog
            // 變成一個永遠不會被翻譯的空 key（體檢 E11）。改成條件式。
            if let message = viewModel.errorMessage { Text(message) }
        }
    }

    // MARK: - 列

    /// 尾欄標籤：**分組依據不在列上重複**（18b）。
    /// 按器材分組時群組標題已經寫了「槓鈴 · 8」，列上再印一次是零資訊——改標肌群，
    /// 位置與 pill 形狀不變。肌群用全名而不是圓章那個兩字縮寫，尾欄放得下。
    private func tailTag(for exercise: Exercise) -> (label: String, identifier: String) {
        switch grouping {
        case .equipment:
            (exercise.muscleGroup.displayName(locale), "muscleTag")
        case .muscle, .frequent, .all:
            (exercise.equipment.displayName(locale), "equipmentTag")
        }
    }

    private func row(for exercise: Exercise) -> some View {
        let tail = tailTag(for: exercise)
        return ExerciseRow(
            name: exercise.name,
            isOfficial: exercise.source == .official,
            tailLabel: tail.label,
            tailIdentifier: tail.identifier,
            deleteLabel: localText("spec.delete"),
            onEdit: { editingTarget = .edit(exercise) },
            onDelete: { Task { await viewModel.remove(id: exercise.id) } }
        )
    }

    /// 內建動作清單常駐之後，動作庫幾乎不可能真的空——會空的是另外兩種情況，
    /// 而「還沒有動作」對它們都是錯的文案，所以分成三種：
    /// 搜尋沒中 → 「找不到符合的動作」；「常用」還沒有資料 → 「還沒有常用動作」。
    private var emptyStateKey: (title: LocalizedStringKey, hint: LocalizedStringKey) {
        if !viewModel.searchText.isEmpty {
            return ("spec.search.empty", "spec.search.empty.hint")
        }
        if grouping == .frequent {
            return ("spec.frequent.empty", "spec.frequent.empty.hint")
        }
        return ("spec.empty", "spec.empty.hint")
    }

    private var emptyState: some View {
        TLInlineEmptyState(
            title: localText(emptyStateKey.title),
            hint: localText(emptyStateKey.hint)
        )
        // 兩種文案共用一個 id：測試要驗的是「空狀態出現了」，文案本身歸 unit test。
        .accessibilityIdentifier("exerciseList.empty")
    }

    // MARK: - 分組（純前端）

    private struct Section: Identifiable {
        let id: String
        let header: Text?
        let exercises: [Exercise]
    }

    private var sections: [Section] {
        let items = viewModel.visibleExercises
        switch grouping {
        case .muscle:
            return MuscleGroup.allCases.compactMap { group in
                let matched = items.filter { $0.muscleGroup == group }
                guard !matched.isEmpty else { return nil }
                return Section(
                    id: "m-\(group.rawValue)",
                    header: sectionHeader(group.displayName(locale), matched.count),
                    exercises: matched
                )
            }
        case .equipment:
            return Equipment.allCases.compactMap { equip in
                let matched = items.filter { $0.equipment == equip }
                guard !matched.isEmpty else { return nil }
                return Section(
                    id: "e-\(equip.rawValue)",
                    header: sectionHeader(equip.displayName(locale), matched.count),
                    exercises: matched
                )
            }
        case .frequent:
            // 依實際練過的場次數排序，沒練過的不列入（見 ExerciseListViewModel.frequentExercises）。
            // 一場都沒練過時這裡會是空的，交給 emptyState 呈現。
            let frequent = viewModel.frequentExercises
            guard !frequent.isEmpty else { return [] }
            return [Section(id: "frequent", header: nil, exercises: frequent)]
        case .all:
            return [Section(id: "all", header: nil, exercises: items)]
        }
    }

    /// 區塊標題「胸 · 4」：組名為 enum 資料（verbatim）＋數量。
    private func sectionHeader(_ name: String, _ count: Int) -> Text {
        Text(verbatim: name) + Text(verbatim: " · \(count)")
    }
}

enum FormTarget: Identifiable {
    case create
    case edit(Exercise)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let exercise): exercise.id.uuidString
        }
    }
}
