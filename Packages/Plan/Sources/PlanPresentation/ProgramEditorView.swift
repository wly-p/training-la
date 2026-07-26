import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

/// 單一長期課表的內容編輯器（設計稿 9c）：套 `EditScaffold`。
/// 本地草稿（名稱／週期天數／每天安排）只在按「儲存」時一次寫回；「總長度」chips 純畫面用，
/// 只決定下方預覽格要畫幾輪，不寫進 Domain（`Program.cycleLength` 才是真正的「週期」）。
/// 不自帶 NavigationStack：由動作庫 tab 共用的 NavigationStack push 進來。
public struct ProgramEditorView: View {
    @Bindable private var viewModel: ProgramEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var draftName = ""
    @State private var draftCycleLength = 7
    @State private var draftDays: [Int: WorkoutSpec] = [:]

    @State private var previewTotalLength = 28
    @State private var isCustomTotalLength = false
    @State private var showCycleLengthEditor = false
    @State private var editingDay: EditingDay?
    @State private var showDeleteConfirm = false

    public init(viewModel: ProgramEditorViewModel) {
        self.viewModel = viewModel
    }

    private var canSave: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (draftName != viewModel.name || draftCycleLength != viewModel.cycleLength || draftDays != viewModel.days)
    }

    public var body: some View {
        EditScaffold(
            title: $draftName,
            titlePrompt: localText("program.name.placeholder"),
            canSave: canSave,
            cancelLabel: localText("plan.cancel"),
            saveLabel: localText("plan.save"),
            onCancel: { dismiss() },
            onSave: {
                Task {
                    if await viewModel.save(name: draftName, cycleLength: draftCycleLength, days: draftDays) {
                        dismiss()
                    }
                }
            }
        ) {
            totalLengthSection
            cycleSection
            previewSection
            deleteSection
        }
        .task {
            await viewModel.load()
            draftName = viewModel.name
            draftCycleLength = viewModel.cycleLength
            draftDays = viewModel.days
            previewTotalLength = [10, 14, 28].first { $0 >= draftCycleLength } ?? draftCycleLength
        }
        .sheet(item: $editingDay) { editing in
            let index = editing.index
            let existing = draftDays[index]
            WorkoutSpecFormView(
                titleKey: "program.dayEdit",
                name: existing?.name ?? "",
                drafts: existing.map { draftsFromBlocks($0.blocks) } ?? [],
                catalog: viewModel.catalog,
                templates: viewModel.templates
            ) { name, drafts in
                draftDays[index] = WorkoutSpec(id: existing?.id ?? UUID(), name: name, sets: PlanSet.make(from: drafts))
            }
        }
        .alert(
            localText("plan.error"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button(role: .cancel) {} label: { localText("plan.ok") }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .tlConfirmationDialog(
            isPresented: $showDeleteConfirm,
            title: localText("program.delete.confirm.title"),
            message: localText("program.delete.confirm.message"),
            confirmLabel: localText("plan.delete"),
            cancelLabel: localText("plan.cancel"),
            role: .destructive,
            confirmIdentifier: "confirmDeleteProgramFromEditor",
            onConfirm: {
                Task {
                    if await viewModel.delete() { dismiss() }
                }
            }
        )
    }

    // MARK: - 總長度（畫面用，決定預覽格畫幾輪，不進 Domain）

    private var totalLengthSection: some View {
        EditSection(localText("program.totalLength.section")) {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach([10, 14, 28], id: \.self) { preset in
                    SelectableChip(
                        totalLengthLabel(preset),
                        isSelected: !isCustomTotalLength && previewTotalLength == preset,
                        selectedFill: TLColor.accent,
                        selectedText: TLColor.bg,
                        onTap: {
                            isCustomTotalLength = false
                            previewTotalLength = preset
                        }
                    )
                }
                SelectableChip(
                    customTotalLengthLabel,
                    isSelected: isCustomTotalLength,
                    selectedFill: TLColor.accent,
                    selectedText: TLColor.bg,
                    onTap: { isCustomTotalLength = true }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isCustomTotalLength {
                Stepper(value: $previewTotalLength, in: max(draftCycleLength, 1)...120) {
                    HStack {
                        localText("program.totalLength.custom")
                        Spacer()
                        Text(verbatim: "\(previewTotalLength)").foregroundStyle(TLColor.neutral600)
                    }
                }
                .padding(.horizontal, TLSpace.rowInset)
            }
        }
    }

    private func totalLengthLabel(_ n: Int) -> String {
        String(localized: "program.totalLength.days \(n)", bundle: .module, locale: locale)
    }

    private var customTotalLengthLabel: String {
        String(localized: "program.totalLength.custom", bundle: .module, locale: locale)
    }

    // MARK: - 週期（真正的 Domain 欄位：cycleLength／days）

    private var cycleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                localText("program.cycle.header \(draftCycleLength)"),
                actionLabel: localText("program.cycle.changeLength"),
                action: { showCycleLengthEditor.toggle() }
            )
            if showCycleLengthEditor {
                Stepper(value: $draftCycleLength, in: 1...60) {
                    HStack {
                        localText("program.cycleLength")
                        Spacer()
                        Text(verbatim: "\(draftCycleLength)").foregroundStyle(TLColor.neutral600)
                    }
                }
                .padding(.horizontal, TLSpace.rowInset)
                .padding(.bottom, 8)
            }
            TLGroup {
                ForEach(Array(0..<draftCycleLength), id: \.self) { index in
                    dayRow(index)
                }
            }
        }
    }

    private func dayRow(_ index: Int) -> some View {
        let spec = draftDays[index]
        return ListRow(
            title: spec.map { Text(verbatim: $0.name) } ?? localText("program.day.rest"),
            subtitle: spec.map { Text(PlanFormatting.summary($0, name: viewModel.name(for:), language: AppLanguage(locale: locale))) },
            showChevron: true,
            onTap: { editingDay = EditingDay(index: index) },
            leading: { indexBadge(index + 1, rest: spec == nil) }
        )
        .contextMenu {
            if spec != nil {
                Button(role: .destructive) {
                    draftDays[index] = nil
                } label: {
                    Label { localText("program.day.setRest") } icon: { Image(systemName: "moon.zzz") }
                }
            }
        }
    }

    private func indexBadge(_ n: Int, rest: Bool) -> some View {
        CircleBadge(fill: rest ? TLColor.neutral200 : TLColor.accent200) {
            Text(verbatim: "\(n)")
                .font(TLFont.display(15))
                .foregroundStyle(rest ? TLColor.neutral500 : TLColor.accent800)
        }
    }

    // MARK: - 預覽格（7 欄 × N 列，填色＝訓練日）

    private var rounds: Int {
        max(1, Int((Double(previewTotalLength) / Double(max(1, draftCycleLength))).rounded()))
    }

    private var practiceCountPerCycle: Int {
        (0..<draftCycleLength).filter { draftDays[$0] != nil }.count
    }

    private var previewSection: some View {
        EditSection(localText("program.preview.section")) {
            VStack(alignment: .leading, spacing: TLSpace.gapM) {
                previewGrid
                previewSummary
                    .font(TLFont.zh(TLFont.rowSub, .semibold))
                    .foregroundStyle(TLColor.neutral700)
            }
            .padding(TLSpace.rowInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TLColor.neutral300)
            .clipShape(RoundedRectangle(cornerRadius: TLRadius.container, style: .continuous))
        }
    }

    private var previewGrid: some View {
        HStack(spacing: 4) {
            ForEach(0..<draftCycleLength, id: \.self) { day in
                VStack(spacing: 4) {
                    ForEach(0..<rounds, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(draftDays[day] != nil ? TLColor.accent : TLColor.neutral100)
                            .frame(width: 18, height: 18)
                    }
                }
            }
        }
    }

    private var previewSummary: Text {
        let restCount = draftCycleLength - practiceCountPerCycle
        return localText("program.preview.cycle \(draftCycleLength)")
            + Text(verbatim: " · ")
            + localText("program.preview.split \(practiceCountPerCycle) \(restCount)")
            + Text(verbatim: " · ")
            + localText("program.preview.repeat \(rounds)")
            + Text(verbatim: " = ")
            + localText("program.preview.total \(rounds * draftCycleLength) \(rounds * practiceCountPerCycle)")
    }

    // MARK: - 刪除

    private var deleteSection: some View {
        TLGroup {
            SettingsRow(
                localText("program.delete.thisProgram"),
                role: .destructive,
                onTap: { showDeleteConfirm = true }
            )
        }
        .accessibilityIdentifier("deleteProgramButton")
    }
}

private struct EditingDay: Identifiable {
    let index: Int
    var id: Int { index }
}
