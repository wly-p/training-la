import AbilityDomain
import DesignSystem
import SharedKernel
import SwiftUI

/// 「我的能力值」清單（handoff-15 F 節）：只列有練過的動作，不是整個動作庫。
///
/// 「能力值」＝該動作實際推過的最大重量，不是估算 1RM。
public struct AbilityListView: View {
    /// 目前語言：`localString` 要靠它才能查到 app 設定的語言（而非手機語系）。
    @Environment(\.locale) private var locale
    @Bindable private var viewModel: AbilityListViewModel
    @State private var editingRow: AbilityListViewModel.Row?
    /// 使用者的重量級距偏好；編輯頁的 ± 與刻度尺跟隨它，不寫死。
    private let weightStep: Double

    public init(viewModel: AbilityListViewModel, weightStep: Double = 2.5) {
        self.viewModel = viewModel
        self.weightStep = weightStep
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageHeader(localText("ability.title"))
                if !viewModel.rows.isEmpty { summaryLine }

                if viewModel.rows.isEmpty {
                    EmptyState(
                        systemImage: "chart.bar.xaxis",
                        title: localString("ability.empty.title", locale),
                        message: localString("ability.empty.message", locale)
                    )
                    .padding(.horizontal, TLSpace.page)
                    .padding(.top, TLSpace.section)
                } else {
                    VStack(alignment: .leading, spacing: TLSpace.gapM) {
                        TLSearchField(text: $viewModel.searchText, placeholder: localText("ability.search"))
                        filterChips
                        rowsGroup
                        localText("ability.footer")
                            .font(TLFont.zh(TLFont.rowSub))
                            .foregroundStyle(TLColor.neutral500)
                            .padding(.horizontal, TLSpace.rowInset)
                    }
                    .padding(.horizontal, TLSpace.page)
                    .padding(.top, TLSpace.gapM)
                }
            }
            .padding(.bottom, 40)
        }
        .background(TLColor.bg.ignoresSafeArea())
        .task { await viewModel.load() }
        .sheet(item: $editingRow) { row in
            AbilityEditSheet(
                row: row,
                weightStep: weightStep,
                onSave: { value in
                    Task {
                        await viewModel.setValue(exerciseId: row.exerciseId, value: value)
                        editingRow = nil
                    }
                }
            )
            // 不用固定 detent：內容比 420pt 高的話工具列會被切掉、連「儲存」都按不到。
            .presentationDetents([.large])
        }
    }

    /// `每個動作推過的最大重量 · N 個動作 · M 個已設定`
    private var summaryLine: some View {
        localText("ability.summary \(viewModel.totalCount) \(viewModel.setCount)")
            .font(TLFont.zh(TLFont.rowSub))
            .foregroundStyle(TLColor.neutral500)
            .padding(.horizontal, TLSpace.page)
            .padding(.top, 2)
    }

    /// 第一顆固定是「未設定 N」——這頁最高頻的任務就是把沒設定的補完。
    /// 沒有任何動作的器材降到 45% 並停用，避免點了得到空清單。
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                unsetChip
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    let enabled = viewModel.hasExercises(for: equipment)
                    MuscleTag(
                        equipment.displayName(locale),
                        isSelected: viewModel.filter == .equipment(equipment),
                        onTap: enabled ? { toggle(.equipment(equipment)) } : nil
                    )
                    .opacity(enabled ? 1 : 0.45)
                    .disabled(!enabled)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var unsetChip: some View {
        let selected = viewModel.filter == .unset
        return Text(verbatim: String(
            format: localString("ability.filter.unset %lld", locale), viewModel.unsetCount
        ))
        .font(TLFont.zh(TLFont.rowSub, .semibold))
        .foregroundStyle(selected ? TLColor.bg : TLColor.accent800)
        .padding(.vertical, 5)
        .padding(.horizontal, 12)
        .background {
            if selected {
                Capsule().fill(TLColor.accent)
            } else {
                Capsule().fill(TLColor.accent200)
            }
        }
        .contentShape(Capsule())
        .onTapGesture { toggle(.unset) }
    }

    /// 再點一次選中的 chip＝取消篩選，不用另外放一顆「全部」。
    private func toggle(_ filter: AbilityListViewModel.Filter) {
        viewModel.filter = viewModel.filter == filter ? .all : filter
    }

    private var rowsGroup: some View {
        TLGroup {
            ForEach(viewModel.visibleRows(locale: locale)) { row in
                // trailing 要具名傳：ListRow 的 leading 排在 trailing 前面，
                // 用尾隨閉包會綁到 leading，值就跑到列的左邊去。
                ListRow(
                    title: Text(verbatim: row.exerciseName),
                    subtitle: subtitle(for: row),
                    equipment: row.equipment.displayName(locale),
                    showChevron: true,
                    onTap: { editingRow = row },
                    trailing: { valueDisplay(for: row) }
                )
            }
        }
    }

    /// 有值＝大數字；沒值＝淡色破折號（不是「尚未設定」四個字——每列都在喊，視覺重量太高）。
    @ViewBuilder
    private func valueDisplay(for row: AbilityListViewModel.Row) -> some View {
        if let value = row.current?.value {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: TLNumberField.format(value.value))
                    .font(TLFont.display(20))
                    .foregroundStyle(TLColor.text)
                Text(verbatim: value.unit.rawValue)
                    .font(TLFont.zh(11.5))
                    .foregroundStyle(TLColor.neutral500)
            }
        } else {
            Text(verbatim: "—")
                .font(TLFont.display(20))
                .foregroundStyle(TLColor.neutral400)
        }
    }

    private func subtitle(for row: AbilityListViewModel.Row) -> Text? {
        guard let current = row.current else {
            guard let suggestion = row.suggestion else { return nil }
            let text = localText("ability.suggestion")
                + Text(verbatim: " \(TLNumberField.format(suggestion.value)) \(suggestion.unit.rawValue)")
            return row.isPerSide ? text + localText("ability.perSide") : text
        }
        let source: Text = switch current.source {
        case .manual: localText("ability.source.manual")
        case .estimated: localText("ability.source.estimated")
        }
        return row.isPerSide ? source + localText("ability.perSide") : source
    }
}

/// 編輯單一動作的能力值（handoff-15 G 節）。
///
/// 舊版的問題：垂直滾輪佔掉半個畫面只為輸入一個數字、`±2.5` 寫死跟設定不一致、
/// 建議值只是一段文字要自己滾過去、sheet 固定 420pt 高導致工具列被切掉按不到儲存。
///
/// 新版：大數字本身就是輸入框，刻度尺只負責微調，建議值變成可以直接按的套用鍵。
private struct AbilityEditSheet: View {
    /// 目前語言：`localString` 要靠它才能查到 app 設定的語言（而非手機語系）。
    @Environment(\.locale) private var locale
    let row: AbilityListViewModel.Row
    /// 使用者的重量級距偏好；± 與刻度尺跟隨它（G 節：不寫死）。
    let weightStep: Double
    let onSave: (Weight) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: Double

    init(row: AbilityListViewModel.Row, weightStep: Double, onSave: @escaping (Weight) -> Void) {
        self.row = row
        self.weightStep = weightStep
        self.onSave = onSave
        // 沒設定過就從建議值起跳，使用者多半直接按儲存就好。
        _value = State(initialValue: row.current?.value.value ?? row.suggestion?.value ?? 60)
    }

    private var unit: WeightUnit { row.current?.value.unit ?? row.suggestion?.unit ?? .kg }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TLSpace.gapL) {
                topBar
                valueCard
                if let suggestion = row.suggestion { applyRow(suggestion) }
                lockNotice
            }
            .padding(TLSpace.page)
        }
        .background(TLColor.bg.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: { localText("ability.cancel") }
                .font(TLFont.zh(15.5, .medium))
                .foregroundStyle(TLColor.neutral600)
            Spacer()
            ExerciseNameWithEquipment(
                name: row.exerciseName,
                equipment: row.equipment.displayName(locale)
            )
            Spacer()
            Button {
                onSave(Weight(value: value, unit: unit))
            } label: {
                localText("ability.done")
            }
            .font(TLFont.zh(15.5, .semibold))
            .foregroundStyle(TLColor.accent700)
        }
    }

    private var valueCard: some View {
        VStack(spacing: TLSpace.gapM) {
            HStack {
                localText("ability.kicker")
                    .font(TLFont.zh(TLFont.kicker, .semibold))
                    .tracking(TLFont.kickerTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(TLColor.neutral500)
                Spacer()
            }
            TLNumberField(
                value: $value,
                unitLabel: unit.rawValue,
                doneLabel: Text("ability.done", bundle: .module)
            )
            localText("ability.tapToType")
                .font(TLFont.zh(TLFont.rowSub))
                .foregroundStyle(TLColor.neutral500)
            TLRulerSlider(
                value: $value,
                step: weightStep,
                range: 0...WeightRange.upperBound(for: unit)
            )
            stepButtons
            localText("ability.stepHint")
                .font(TLFont.zh(11.5))
                .foregroundStyle(TLColor.neutral500)
                .multilineTextAlignment(.center)
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.neutral100)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }

    private var stepButtons: some View {
        HStack(spacing: TLSpace.gapM) {
            stepButton(-weightStep)
            stepButton(weightStep)
        }
    }

    /// 長按連續調整（G 節）：從 20 調到 180 不用按幾十下。
    private func stepButton(_ delta: Double) -> some View {
        let label = (delta < 0 ? "−" : "+") + TLNumberField.format(abs(delta))
        return Button {
            bump(delta)
        } label: {
            Text(verbatim: label)
                .font(TLFont.zh(TLFont.rowTitle, .semibold))
                .foregroundStyle(TLColor.accent700)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(TLColor.neutral100))
                .overlay(Capsule().strokeBorder(TLColor.text.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.4, perform: {}, onPressingChanged: { pressing in
            guard pressing else { return }
            repeatBump(delta)
        })
    }

    private func bump(_ delta: Double) {
        value = WeightRange.clamped(value + delta, unit: unit)
    }

    /// 按住不放時每 0.12 秒加一次；放開由 SwiftUI 取消這個 Task。
    @State private var repeatTask: Task<Void, Never>?
    private func repeatBump(_ delta: Double) {
        repeatTask?.cancel()
        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            while !Task.isCancelled {
                bump(delta)
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    /// 建議值改成可以直接按的套用鍵，不再是一段要自己照著滾的文字。
    private func applyRow(_ suggestion: Weight) -> some View {
        HStack {
            (localText("ability.lastPerformed")
                + Text(verbatim: " \(TLNumberField.format(row.lastWeight.value)) \(row.lastWeight.unit.rawValue) × \(row.lastReps)"))
                .font(TLFont.zh(TLFont.rowSub))
                .foregroundStyle(TLColor.text)
            Spacer(minLength: TLSpace.gapS)
            Button {
                value = suggestion.value
            } label: {
                Text(verbatim: String(
                    format: localString("ability.apply %@", locale),
                    TLNumberField.format(suggestion.value)
                ))
                .font(TLFont.zh(TLFont.rowSub, .semibold))
                .foregroundStyle(TLColor.bg)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(Capsule().fill(TLColor.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(TLSpace.rowInset)
        .background(TLColor.accent200)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
    }

    private var lockNotice: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(TLColor.neutral500)
            localText("ability.editNote")
                .font(TLFont.zh(TLFont.rowSub))
                .foregroundStyle(TLColor.neutral500)
        }
    }
}
