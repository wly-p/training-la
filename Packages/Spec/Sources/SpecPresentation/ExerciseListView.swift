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
                if viewModel.visibleExercises.isEmpty {
                    emptyState
                        .padding(.horizontal, TLSpace.page)
                        .padding(.top, TLSpace.gapL)
                } else {
                    LazyVStack(alignment: .leading, spacing: TLSpace.section) {
                        ForEach(sections, id: \.id) { section in
                            VStack(alignment: .leading, spacing: 0) {
                                if let header = section.header {
                                    SectionHeader(header)
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
                    .padding(.bottom, 40)
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

    @ViewBuilder
    private func row(for exercise: Exercise) -> some View {
        // 內建動作（OfficialExerciseCatalog）唯讀：不進編輯表單、沒有刪除選單，
        // 也不顯示 chevron——留著箭頭卻點不動比沒有箭頭更難懂。
        let isOfficial = exercise.source == .official
        ListRow(
            title: Text(verbatim: exercise.name),
            showChevron: !isOfficial,
            onTap: isOfficial ? nil : { editingTarget = .edit(exercise) },
            trailing: {
                // 18b：唯一的彩色元素，固定尾欄靠右。
                // 80pt 是「槓鈴」「機械」那些兩字標籤的欄寬，但「自體重量」比它寬——用 minWidth
                // 讓長標往左長、右緣仍然對齊；寫死 width 會把長標壓成兩行。
                let tail = tailTag(for: exercise)
                EquipmentTag(tail.label, identifier: tail.identifier)
                    .frame(minWidth: 80, alignment: .trailing)
            }
        )
        // 內建動作的名稱會跟著 app 語言換，測試沒辦法用名字找到它——改認這個 id。
        // 使用者自建的動作名是測試自己輸入的資料，照舊用文字定位。
        .accessibilityIdentifier(isOfficial ? "exerciseList.officialRow" : "exerciseList.row")
        // 整個 modifier 拿掉、而不是留一個空的 menu：空 menu 長按仍會有抬起動畫卻沒有選項。
        .contextMenu(isOfficial ? nil : ContextMenu {
            Button(role: .destructive) {
                Task { await viewModel.remove(id: exercise.id) }
            } label: {
                Label { localText("spec.delete") } icon: { Image(systemName: "trash") }
            }
            .accessibilityIdentifier("exerciseList.delete")
        })
    }

    /// 內建動作清單常駐之後，動作庫幾乎不可能真的空——唯一會空的是搜尋沒中，
    /// 那時候「還沒有動作」是錯的文案，所以分成兩種。
    private var emptyState: some View {
        VStack(spacing: 8) {
            localText(viewModel.searchText.isEmpty ? "spec.empty" : "spec.search.empty")
                .font(TLFont.zh(16, .bold))
                .foregroundStyle(TLColor.text)
            localText(viewModel.searchText.isEmpty ? "spec.empty.hint" : "spec.search.empty.hint")
                .font(TLFont.zh(12.5, .regular))
                .foregroundStyle(TLColor.neutral600)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
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
            // TODO 假資料：目前無「使用頻率」資料（Domain/Data 未實作），暫取清單前段當「常用」。
            // 接上使用頻率統計後改成真正依次數排序。
            let frequent = Array(items.prefix(8))
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
