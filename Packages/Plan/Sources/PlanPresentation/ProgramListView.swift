import PlanDomain
import SharedKernel
import SwiftUI

/// 動作庫「長期課表」分段的根：多份長期課表清單，建立/刪除；點進去編輯 N 天週期內容。
/// 套用到月曆（選起始日/模式）在課表 tab，不在這裡。
public struct ProgramListView: View {
    @Bindable private var viewModel: ProgramListViewModel
    private let makeEditor: @MainActor (UUID) -> ProgramEditorViewModel
    @State private var creating = false

    public init(
        viewModel: ProgramListViewModel,
        makeEditor: @escaping @MainActor (UUID) -> ProgramEditorViewModel
    ) {
        self.viewModel = viewModel
        self.makeEditor = makeEditor
    }

    public var body: some View {
        List {
            ForEach(viewModel.programs) { program in
                NavigationLink {
                    ProgramEditorView(viewModel: makeEditor(program.id))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        // 課表名是使用者資料（verbatim）
                        Text(verbatim: program.name).font(.headline)
                        cycleSummary(program)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.delete(id: program.id) }
                    } label: {
                        localText("plan.delete")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creating = true
                } label: {
                    Label { localText("program.list.new") } icon: { Image(systemName: "plus") }
                }
            }
        }
        .overlay {
            if viewModel.programs.isEmpty {
                ContentUnavailableView {
                    Label { localText("program.empty") } icon: { Image(systemName: "calendar.badge.clock") }
                } description: {
                    localText("program.empty.hint")
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $creating) {
            ProgramCreateFormView { name, cycleLength in
                await viewModel.create(name: name, cycleLength: cycleLength)
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
    }

    private func cycleSummary(_ program: Program) -> Text {
        let workoutDays = program.days.count
        let format = String(localized: "program.summary \(program.cycleLength) \(workoutDays)", bundle: .module)
        return Text(format)
    }
}

/// 建立長期課表：名稱 + 週期天數。
private struct ProgramCreateFormView: View {
    let onSubmit: (String, Int) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var cycleLength = 7

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("", text: $name, prompt: localText("program.name.placeholder"))
                }
                Section {
                    Stepper(value: $cycleLength, in: 1...60) {
                        HStack {
                            localText("program.cycleLength")
                            Spacer()
                            Text(verbatim: "\(cycleLength)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    localText("program.cycleLength.hint")
                }
            }
            .navigationTitle(localText("program.list.new"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("plan.cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await onSubmit(name, cycleLength); dismiss() }
                    } label: {
                        localText("plan.save")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
