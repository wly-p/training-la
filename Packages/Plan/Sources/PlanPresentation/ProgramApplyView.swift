import DesignSystem
import PlanDomain
import SharedKernel
import SwiftUI

/// 套用長期課表到月曆（課表「+」→ 長期）：選課表 ＋ 起始日 ＋ 模式（跑一次／重複），也可停用已套用的。
/// 套動作庫同一套 DesignSystem 元件（`TLGroup`／`ListRow`／`TLSegmentedControl`／`.tlPrimary`），
/// 取代原生 `Form`。這頁沒有可編輯的「名稱」，故不套 `EditScaffold`，改自訂頂列。
struct ProgramApplyView: View {
    let programs: [Program]
    let assignments: [ProgramAssignment]
    let defaultStartDate: DayDate
    let programName: (ProgramAssignment) -> String
    let onApply: (UUID, DayDate, ProgramRunMode) async -> Void
    let onStop: (UUID) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProgramId: UUID?
    @State private var startDate: Date
    @State private var mode: ProgramRunMode = .repeating

    init(
        programs: [Program],
        assignments: [ProgramAssignment],
        defaultStartDate: DayDate,
        programName: @escaping (ProgramAssignment) -> String,
        onApply: @escaping (UUID, DayDate, ProgramRunMode) async -> Void,
        onStop: @escaping (UUID) async -> Void
    ) {
        self.programs = programs
        self.assignments = assignments
        self.defaultStartDate = defaultStartDate
        self.programName = programName
        self.onApply = onApply
        self.onStop = onStop
        _selectedProgramId = State(initialValue: programs.first?.id)
        _startDate = State(initialValue: defaultStartDate.asDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    localText("plan.close")
                        .font(TLFont.zh(15.5, .medium))
                        .foregroundStyle(TLColor.neutral600)
                }
                Spacer()
            }
            .padding(.horizontal, TLSpace.page)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: TLSpace.section) {
                    localText("plan.applyProgram")
                        .font(TLFont.zh(TLFont.pageTitle, .bold))
                        .foregroundStyle(TLColor.text)

                    if programs.isEmpty {
                        localText("program.apply.none")
                            .font(TLFont.zh(TLFont.rowSub, .regular))
                            .foregroundStyle(TLColor.neutral500)
                    } else {
                        applyForm
                    }
                    if !assignments.isEmpty {
                        activeSection
                    }
                }
                .padding(.horizontal, TLSpace.page)
                .padding(.top, TLSpace.gapL)
                .padding(.bottom, 40)
            }
        }
        .background(TLColor.bg.ignoresSafeArea())
    }

    private var applyForm: some View {
        VStack(alignment: .leading, spacing: TLSpace.section) {
            EditSection(localText("program.apply.pick")) {
                TLGroup {
                    ForEach(programs) { program in
                        ListRow(
                            title: Text(verbatim: program.name),
                            onTap: { selectedProgramId = program.id },
                            leading: { CheckBadge(isChecked: selectedProgramId == program.id) }
                        )
                    }
                }
            }

            EditSection(localText("program.apply.startDate")) {
                TLGroup {
                    HStack {
                        localText("program.apply.startDate")
                            .font(TLFont.zh(TLFont.rowTitle))
                            .foregroundStyle(TLColor.text)
                        Spacer()
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                            .tint(TLColor.accent)
                    }
                    .padding(.horizontal, TLSpace.rowInset)
                    .frame(minHeight: TLSize.row)
                }
            }

            EditSection(localText("program.apply.mode")) {
                TLSegmentedControl(
                    selection: $mode,
                    options: [
                        .init(ProgramRunMode.repeating, localText("program.mode.repeating")),
                        .init(ProgramRunMode.once, localText("program.mode.once")),
                    ]
                )
            }

            Button {
                guard let id = selectedProgramId else { return }
                Task {
                    await onApply(id, DayDate(startDate), mode)
                    dismiss()
                }
            } label: {
                localText("program.apply.confirm").frame(maxWidth: .infinity)
            }
            .buttonStyle(.tlPrimary)
            .disabled(selectedProgramId == nil)

            localText("program.apply.hint")
                .font(TLFont.zh(TLFont.rowSub, .regular))
                .foregroundStyle(TLColor.neutral500)
        }
    }

    private var activeSection: some View {
        EditSection(localText("program.apply.activeHeader")) {
            TLGroup {
                ForEach(assignments) { assignment in
                    HStack(spacing: TLSpace.gapM) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: programName(assignment))
                                .font(TLFont.zh(TLFont.rowTitle, .semibold))
                                .foregroundStyle(TLColor.text)
                            (Text(verbatim: assignment.startDate.isoString + " · ")
                                + localText(assignment.mode == .repeating ? "program.mode.repeating" : "program.mode.once"))
                                .font(TLFont.zh(TLFont.rowSub, .regular))
                                .foregroundStyle(TLColor.neutral500)
                        }
                        Spacer(minLength: TLSpace.gapS)
                        Button(role: .destructive) {
                            Task { await onStop(assignment.id) }
                        } label: {
                            localText("program.apply.stop")
                                .font(TLFont.zh(TLFont.rowSub, .semibold))
                                .foregroundStyle(TLColor.danger700)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, TLSpace.rowInset)
                    .frame(minHeight: TLSize.rowWithSub)
                }
            }
        }
    }
}
