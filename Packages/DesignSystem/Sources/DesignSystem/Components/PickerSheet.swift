import SwiftUI

/// G2 共用選擇器 sheet（設計稿 12c/12d）：範本加動作(9b)、循環加範本(12a)、長期指派週期格(12b)
/// 共用同一個元件，差別只在資料源／單選或多選／底部按鈕文案。
///
/// - 搜尋框 ＋ 可選篩選膠囊（肌群）橫向捲動
/// - 分組清單：「最近用過」／「全部 · 篩選標籤」（`sections` 由呼叫端依目前搜尋字＋篩選算好傳入）
/// - 多選：列左側勾選圈，底部常駐主要按鈕；單選：點一列即關閉，無底部按鈕
/// - 右上「新建」＋搜尋時清單最後一列「新建「X」」：就地新增，交給呼叫端處理
public struct PickerSheet<Item: PickerSheetItem>: View {
    public enum Selection {
        /// 多選＋一次加入：`confirmLabel` 依已選數量給文字（`加入 N 個動作`）。
        case multiple(selectedIds: Binding<Set<Item.ID>>, confirmLabel: (Int) -> Text, onConfirm: () -> Void)
        /// 單選，點一列即關閉（不用底部按鈕）。
        case single(onSelect: (Item) -> Void)
    }

    private let title: Text
    private let searchPrompt: Text
    private let allItems: [Item]
    private let recentItemIds: [Item.ID]
    private let filters: [PickerSheetFilterChip]
    private let matchesFilter: (Item, PickerSheetFilterChip) -> Bool
    private let selection: Selection
    private let onCreateNew: ((String) -> Void)?
    private let labels: PickerSheetLabels

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedFilterId: String?

    public init(
        title: Text,
        searchPrompt: Text,
        allItems: [Item],
        recentItemIds: [Item.ID] = [],
        filters: [PickerSheetFilterChip] = [],
        matchesFilter: @escaping (Item, PickerSheetFilterChip) -> Bool = { _, _ in true },
        selection: Selection,
        onCreateNew: ((String) -> Void)? = nil,
        labels: PickerSheetLabels
    ) {
        self.title = title
        self.searchPrompt = searchPrompt
        self.allItems = allItems
        self.recentItemIds = recentItemIds
        self.filters = filters
        self.matchesFilter = matchesFilter
        self.selection = selection
        self.onCreateNew = onCreateNew
        self.labels = labels
    }

    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    private var searchFiltered: [Item] {
        guard isSearching else { return allItems }
        return allItems.filter { $0.title.localizedStandardContains(searchText) || $0.subtitle.localizedStandardContains(searchText) }
    }

    private var recentItems: [Item] {
        guard !isSearching else { return [] }
        let ids = Set(recentItemIds)
        return allItems.filter { ids.contains($0.id) }
    }

    private var mainItems: [Item] {
        let base = isSearching ? searchFiltered : allItems.filter { !recentItemIds.contains($0.id) }
        guard let filterId = selectedFilterId, let filter = filters.first(where: { $0.id == filterId }) else { return base }
        return base.filter { matchesFilter($0, filter) }
    }

    private var allSectionTitle: Text {
        labels.allSection(filters.first { $0.id == selectedFilterId })
    }

    public var body: some View {
        VStack(spacing: 0) {
            grabber
            topBar
            TLSearchField(text: $searchText, placeholder: searchPrompt, identifier: "picker.search")
                .padding(.horizontal, TLSpace.page)
                .padding(.top, TLSpace.gapM)
            if isSearching {
                matchCountLine
            } else if !filters.isEmpty {
                filterRow
            }
            ScrollView {
                VStack(alignment: .leading, spacing: TLSpace.gapL) {
                    if !recentItems.isEmpty {
                        section(title: labels.recentSection, items: recentItems)
                    }
                    section(title: allSectionTitle, items: mainItems)
                    if let onCreateNew, isSearching {
                        createNewRow(onCreateNew)
                    }
                }
                .padding(.horizontal, TLSpace.page)
                .padding(.top, TLSpace.gapM)
                .padding(.bottom, bottomButtonReservedHeight)
            }
        }
        .background(TLColor.bg.ignoresSafeArea())
        .overlay(alignment: .bottom) { bottomButton }
    }

    // MARK: - 頂部

    private var grabber: some View {
        Capsule()
            .fill(TLColor.neutral400)
            .frame(width: 38, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: { labels.cancel }
                .font(TLFont.zh(15.5, .medium))
                .foregroundStyle(TLColor.neutral600)
            Spacer()
            title
                .font(TLFont.zh(TLFont.rowTitle, .semibold))
                .foregroundStyle(TLColor.text)
                // 測試用它判斷 sheet 開了沒；標題文字各處不同又會跟著語言換，所以認 id。
                .accessibilityIdentifier("picker.title")
            Spacer()
            if let onCreateNew {
                Button {
                    onCreateNew(searchText)
                } label: {
                    labels.createNewButton
                }
                .font(TLFont.zh(15.5, .bold))
                .foregroundStyle(TLColor.accent700)
            } else {
                // 佔位：讓標題保持水平居中
                labels.cancel.opacity(0)
            }
        }
        .padding(.horizontal, TLSpace.page)
        .padding(.bottom, TLSpace.gapS)
    }

    private var matchCountLine: some View {
        labels.matchCount(searchFiltered.count)
            .font(TLFont.zh(TLFont.rowSub, .regular))
            .foregroundStyle(TLColor.neutral500)
            .padding(.horizontal, TLSpace.page)
            .padding(.top, 6)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters) { filter in
                    SelectableChip(
                        filter.label,
                        isSelected: selectedFilterId == filter.id,
                        selectedFill: TLColor.sage200,
                        selectedText: TLColor.sage800,
                        onTap: { selectedFilterId = selectedFilterId == filter.id ? nil : filter.id }
                    )
                }
            }
            .padding(.horizontal, TLSpace.page)
        }
        .padding(.top, TLSpace.gapM)
    }

    // MARK: - 清單

    private func section(title: Text, items: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title)
            TLGroup {
                ForEach(items) { item in
                    row(item)
                }
            }
        }
    }

    private func row(_ item: Item) -> some View {
        Group {
            switch selection {
            case .multiple(let selectedIds, _, _):
                Button {
                    if selectedIds.wrappedValue.contains(item.id) {
                        selectedIds.wrappedValue.remove(item.id)
                    } else {
                        selectedIds.wrappedValue.insert(item.id)
                    }
                } label: {
                    rowContent(item, isSelected: selectedIds.wrappedValue.contains(item.id))
                }
                .buttonStyle(.plain)
            case .single(let onSelect):
                Button {
                    onSelect(item)
                    dismiss()
                } label: {
                    rowContent(item, isSelected: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func rowContent(_ item: Item, isSelected: Bool) -> some View {
        HStack(spacing: TLSpace.gapM) {
            if case .multiple = selection {
                CheckBadge(isChecked: isSelected)
            }
            VStack(alignment: .leading, spacing: 2) {
                highlightedTitle(item.title)
                    .font(TLFont.zh(TLFont.rowTitle))
                    .foregroundStyle(TLColor.text)
                Text(verbatim: item.subtitle)
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral500)
            }
            Spacer(minLength: TLSpace.gapS)
            if let note = item.trailingNote {
                Text(verbatim: note)
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral500)
            }
        }
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }

    /// 搜尋時把相符字串用 `accent-200` 底標出。
    private func highlightedTitle(_ title: String) -> Text {
        guard isSearching, let range = title.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return Text(verbatim: title)
        }
        let before = String(title[title.startIndex..<range.lowerBound])
        let matched = String(title[range])
        let after = String(title[range.upperBound...])
        return Text(verbatim: before) + Text(verbatim: matched).foregroundStyle(TLColor.accent800) + Text(verbatim: after)
    }

    private func createNewRow(_ onCreateNew: @escaping (String) -> Void) -> some View {
        Button {
            onCreateNew(searchText)
        } label: {
            HStack(spacing: TLSpace.gapM) {
                CircleBadge(icon: "plus", fill: TLColor.neutral200, tint: TLColor.neutral600)
                labels.createNewRow(searchText)
                    .font(TLFont.zh(TLFont.rowTitle, .semibold))
                    .foregroundStyle(TLColor.accent700)
                Spacer()
            }
            .padding(.horizontal, TLSpace.rowInset)
            .frame(minHeight: TLSize.row)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 底部按鈕（多選才有）

    private var bottomButtonReservedHeight: CGFloat {
        if case .multiple = selection { return 76 } else { return 24 }
    }

    @ViewBuilder
    private var bottomButton: some View {
        if case .multiple(let selectedIds, let confirmLabel, let onConfirm) = selection {
            let count = selectedIds.wrappedValue.count
            Button {
                onConfirm()
                dismiss()
            } label: {
                confirmLabel(count)
                    .font(TLFont.zh(TLFont.rowTitle, .bold))
                    .foregroundStyle(TLColor.bg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(count > 0 ? TLColor.accent : TLColor.neutral400)
                    .clipShape(Capsule())
            }
            .disabled(count == 0)
            // 標題帶已選數量（「加入 2 個動作」），拿文字定位會綁死語言＋數量。
            .accessibilityIdentifier("picker.confirm")
            .padding(.horizontal, TLSpace.page)
            .padding(.bottom, 12)
            .padding(.top, 16)
            .background(
                LinearGradient(colors: [TLColor.bg.opacity(0), TLColor.bg], startPoint: .top, endPoint: .bottom)
                    .frame(height: 90)
                    .allowsHitTesting(false),
                alignment: .top
            )
        }
    }
}

/// `PickerSheet` 的資料項協議：只需要標題／副標／可選右側說明文字。
public protocol PickerSheetItem: Identifiable {
    var title: String { get }
    var subtitle: String { get }
    /// 右側說明（如「已在此範本」）；多數情境用 nil。
    var trailingNote: String? { get }
}

public extension PickerSheetItem {
    var trailingNote: String? { nil }
}

/// 篩選膠囊（如肌群）。獨立於 `PickerSheet<Item>` 之外，讓不同 Item 型別的 picker 能共用同一套
/// `PickerSheetLabels`（若巢狀在 generic 型別裡，每個 Item 具現化會各自算一個型別，無法共用實例）。
public struct PickerSheetFilterChip: Identifiable, Sendable {
    public let id: String
    public let label: String
    public init(id: String, label: String) { self.id = id; self.label = label }
}

/// 固定文字（取消／新建／最近用過／全部…）由呼叫端傳入，元件本身不吃 i18n
/// （DesignSystem 沒有自己的 String Catalog，跟 `EditScaffold` 等元件同一慣例）。
/// 存成 `static let` 跨情境共用時要求 `Sendable`，故 closure 都標 `@Sendable`。
public struct PickerSheetLabels: Sendable {
    public let cancel: Text
    public let createNewButton: Text
    public let recentSection: Text
    public let allSection: @Sendable (PickerSheetFilterChip?) -> Text
    public let matchCount: @Sendable (Int) -> Text
    public let createNewRow: @Sendable (String) -> Text
    public init(
        cancel: Text,
        createNewButton: Text,
        recentSection: Text,
        allSection: @escaping @Sendable (PickerSheetFilterChip?) -> Text,
        matchCount: @escaping @Sendable (Int) -> Text,
        createNewRow: @escaping @Sendable (String) -> Text
    ) {
        self.cancel = cancel
        self.createNewButton = createNewButton
        self.recentSection = recentSection
        self.allSection = allSection
        self.matchCount = matchCount
        self.createNewRow = createNewRow
    }
}
