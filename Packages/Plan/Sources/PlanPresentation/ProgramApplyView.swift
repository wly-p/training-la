import PlanDomain
import SharedKernel
import SwiftUI

/// 套用長期課表到月曆：選課表 + 起始日 + 模式（跑一次/重複）。也可停用已套用的。
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
        NavigationStack {
            Form {
                if programs.isEmpty {
                    Section {
                        localText("program.apply.none").foregroundStyle(.secondary)
                    }
                } else {
                    applySection
                }
                if !assignments.isEmpty {
                    activeSection
                }
            }
            .navigationTitle(localText("plan.applyProgram"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("plan.close") }
                }
            }
        }
    }

    private var applySection: some View {
        Section {
            Picker(selection: $selectedProgramId) {
                ForEach(programs) { program in
                    Text(verbatim: program.name).tag(Optional(program.id))
                }
            } label: {
                localText("program.apply.pick")
            }
            DatePicker(selection: $startDate, displayedComponents: .date) {
                localText("program.apply.startDate")
            }
            Picker(selection: $mode) {
                localText("program.mode.repeating").tag(ProgramRunMode.repeating)
                localText("program.mode.once").tag(ProgramRunMode.once)
            } label: {
                localText("program.apply.mode")
            }
            .pickerStyle(.segmented)
            Button {
                guard let id = selectedProgramId else { return }
                Task {
                    await onApply(id, DayDate(startDate), mode)
                    dismiss()
                }
            } label: {
                localText("program.apply.confirm")
            }
            .disabled(selectedProgramId == nil)
        } footer: {
            localText("program.apply.hint")
        }
    }

    private var activeSection: some View {
        Section {
            ForEach(assignments) { assignment in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: programName(assignment)).font(.subheadline)
                        HStack(spacing: 6) {
                            Text(verbatim: assignment.startDate.isoString)
                            localText(assignment.mode == .repeating ? "program.mode.repeating" : "program.mode.once")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        Task { await onStop(assignment.id) }
                    } label: {
                        localText("program.apply.stop")
                    }
                    .buttonStyle(.borderless)
                }
            }
        } header: {
            localText("program.apply.activeHeader")
        }
    }
}
