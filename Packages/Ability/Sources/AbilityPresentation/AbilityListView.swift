import AbilityDomain
import DesignSystem
import SharedKernel
import SwiftUI

/// 「我的能力值」清單（05-settings.md B 節）：只列有練過的動作，不是整個動作庫。
/// 落點暫定掛在設定分頁底下（設計文件標「待決定」），由呼叫端（App 層）決定怎麼進來。
public struct AbilityListView: View {
    @Bindable private var viewModel: AbilityListViewModel
    @State private var editingRow: AbilityListViewModel.Row?

    public init(viewModel: AbilityListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageHeader(localText("ability.title"))

                if viewModel.rows.isEmpty {
                    EmptyState(
                        systemImage: "chart.bar.xaxis",
                        title: String(localized: "ability.empty.title", bundle: .module),
                        message: String(localized: "ability.empty.message", bundle: .module)
                    )
                    .padding(.horizontal, TLSpace.page)
                    .padding(.top, TLSpace.section)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        TLGroup {
                            ForEach(viewModel.rows) { row in
                                ListRow(
                                    title: Text(verbatim: row.exerciseName),
                                    subtitle: subtitle(for: row),
                                    showChevron: true,
                                    onTap: { editingRow = row }
                                ) {
                                    if let value = row.current?.value {
                                        RowValue(formatNumber(value.value), unit: value.unit.rawValue)
                                    } else {
                                        localText("ability.notSet")
                                            .font(TLFont.zh(TLFont.rowSub))
                                            .foregroundStyle(TLColor.neutral500)
                                    }
                                }
                            }
                        }
                        localText("ability.footer")
                            .font(TLFont.zh(TLFont.rowSub))
                            .foregroundStyle(TLColor.neutral500)
                            .padding(.horizontal, TLSpace.rowInset)
                    }
                    .padding(.horizontal, TLSpace.page)
                    .padding(.top, TLSpace.section)
                }
            }
            .padding(.bottom, 40)
        }
        .background(TLColor.bg.ignoresSafeArea())
        .task { await viewModel.load() }
        .sheet(item: $editingRow) { row in
            AbilityEditSheet(row: row, onSave: { value in
                Task {
                    await viewModel.setValue(exerciseId: row.exerciseId, value: value)
                    editingRow = nil
                }
            }, onAcceptSuggestion: {
                Task {
                    await viewModel.acceptSuggestion(row)
                    editingRow = nil
                }
            })
            .presentationDetents([.height(420)])
        }
    }

    private func subtitle(for row: AbilityListViewModel.Row) -> Text? {
        guard let current = row.current else {
            guard let suggestion = row.suggestion else { return nil }
            return localText("ability.suggestion") + Text(verbatim: " \(formatNumber(suggestion.value))\(suggestion.unit.rawValue)")
        }
        switch current.source {
        case .manual: return localText("ability.source.manual")
        case .estimated: return localText("ability.source.estimated")
        }
    }

    private func formatNumber(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }
}

/// 編輯單一動作的能力值：ValuePicker 選公斤，或直接接受推算建議。
private struct AbilityEditSheet: View {
    let row: AbilityListViewModel.Row
    let onSave: (Weight) -> Void
    let onAcceptSuggestion: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: Double

    init(row: AbilityListViewModel.Row, onSave: @escaping (Weight) -> Void, onAcceptSuggestion: @escaping () -> Void) {
        self.row = row
        self.onSave = onSave
        self.onAcceptSuggestion = onAcceptSuggestion
        _value = State(initialValue: row.current?.value.value ?? row.suggestion?.value ?? 60)
    }

    private var values: [Double] { Array(stride(from: 0, through: 300, by: 2.5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapL) {
            topBar
            if let suggestion = row.suggestion {
                Button {
                    onAcceptSuggestion()
                } label: {
                    (localText("ability.suggestionBanner") + Text(verbatim: " \(formatNumber(suggestion.value))\(suggestion.unit.rawValue)"))
                        .font(TLFont.zh(TLFont.rowSub, .semibold))
                        .foregroundStyle(TLColor.accent700)
                }
                .padding(TLSpace.rowInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TLColor.accent200)
                .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
            }
            ValuePicker(
                value: $value,
                values: values,
                kicker: String(localized: "ability.kicker", bundle: .module),
                quickActions: [
                    .init("-2.5") { value = max(values.first ?? 0, value - 2.5) },
                    .init("+2.5") { value = min(values.last ?? 0, value + 2.5) },
                ]
            )
            localText("ability.editNote")
                .font(TLFont.zh(TLFont.rowSub))
                .foregroundStyle(TLColor.neutral500)
        }
        .padding(TLSpace.page)
        .padding(.top, TLSpace.gapL)
        .background(TLColor.bg.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: { localText("ability.cancel") }
                .font(TLFont.zh(15.5, .medium))
                .foregroundStyle(TLColor.neutral600)
            Spacer()
            Text(verbatim: row.exerciseName)
                .font(TLFont.zh(TLFont.rowTitle, .semibold))
                .foregroundStyle(TLColor.text)
            Spacer()
            Button {
                onSave(Weight(value: value, unit: .kg))
            } label: {
                localText("ability.done")
            }
            .font(TLFont.zh(15.5, .bold))
            .foregroundStyle(TLColor.accent700)
        }
    }

    private func formatNumber(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }
}
