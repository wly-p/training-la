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
            ])
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
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - 列

    @ViewBuilder
    private func row(for exercise: Exercise) -> some View {
        // 內建動作（OfficialExerciseCatalog）唯讀：不進編輯表單、沒有刪除選單，
        // 也不顯示 chevron——留著箭頭卻點不動比沒有箭頭更難懂。
        let isOfficial = exercise.source == .official
        ListRow(
            // 器材從右欄灰字移到名稱右側的 pill（handoff-15 15c）——右欄那個位置離名稱太遠，
            // 同名動作要左右來回對才看得出差別。
            title: Text(verbatim: exercise.name),
            equipment: exercise.equipment.displayName(locale),
            showChevron: !isOfficial,
            onTap: isOfficial ? nil : { editingTarget = .edit(exercise) },
            leading: {
                // 肌群縮寫圓章（sage）。displayName 可能多字（功能性訓練／核心），圓章取前二字。
                CircleBadge(muscle: exercise.muscleGroup.badgeText(locale))
            }
        )
        // 整個 modifier 拿掉、而不是留一個空的 menu：空 menu 長按仍會有抬起動畫卻沒有選項。
        .contextMenu(isOfficial ? nil : ContextMenu {
            Button(role: .destructive) {
                Task { await viewModel.remove(id: exercise.id) }
            } label: {
                Label { localText("spec.delete") } icon: { Image(systemName: "trash") }
            }
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
