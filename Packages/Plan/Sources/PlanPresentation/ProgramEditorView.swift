import PlanDomain
import SharedKernel
import SwiftUI

/// 單一長期課表的內容編輯器：改名、調週期天數、逐天指定 workout 或休息。
/// 不自帶 NavigationStack：由動作庫 tab 共用的 NavigationStack push 進來。
public struct ProgramEditorView: View {
    @Bindable private var viewModel: ProgramEditorViewModel
    @State private var editingDay: EditingDay?
    @State private var draftName: String = ""
    @Environment(\.locale) private var locale

    public init(viewModel: ProgramEditorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            Section {
                TextField("", text: $draftName, prompt: localText("program.name.placeholder"))
                    .onSubmit { Task { await viewModel.rename(draftName) } }
                Stepper(value: cycleLengthBinding, in: 1...60) {
                    HStack {
                        localText("program.cycleLength")
                        Spacer()
                        Text(verbatim: "\(viewModel.cycleLength)").foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                ForEach(Array(0..<viewModel.cycleLength), id: \.self) { index in
                    dayRow(index)
                }
            } header: {
                localText("program.days.header")
            } footer: {
                localText("program.days.footer")
            }
        }
        // 課表名是使用者資料（verbatim）
        .navigationTitle(Text(verbatim: viewModel.name))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await viewModel.load()
            draftName = viewModel.name
        }
        .sheet(item: $editingDay) { editing in
            let index = editing.index
            let existing = viewModel.workout(day: index)
            WorkoutSpecFormView(
                titleKey: "program.dayEdit",
                name: existing?.name ?? "",
                drafts: existing.map { draftsFromBlocks($0.blocks) } ?? [],
                catalog: viewModel.catalog,
                templates: viewModel.templates
            ) { name, drafts in
                Task { await viewModel.setDay(index, name: name, drafts: drafts) }
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

    private var cycleLengthBinding: Binding<Int> {
        Binding(
            get: { viewModel.cycleLength },
            set: { newValue in Task { await viewModel.setCycleLength(newValue) } }
        )
    }

    @ViewBuilder
    private func dayRow(_ index: Int) -> some View {
        let spec = viewModel.workout(day: index)
        Button {
            editingDay = EditingDay(index: index)
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(dayLabel(index)).font(.subheadline.weight(.medium))
                    .frame(minWidth: 56, alignment: .leading)
                if let spec {
                    VStack(alignment: .leading, spacing: 2) {
                        // workout 名是使用者資料（verbatim）
                        Text(verbatim: spec.name).font(.body)
                        Text(PlanFormatting.summary(spec, name: viewModel.name(for:), language: AppLanguage(locale: locale)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    localText("program.rest").foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            if spec != nil {
                Button {
                    Task { await viewModel.clearDay(index) }
                } label: {
                    localText("program.clearDay")
                }
                .tint(.gray)
            }
        }
    }

    private func dayLabel(_ index: Int) -> String {
        String(localized: "program.day \(index + 1)", bundle: .module, locale: locale)
    }
}

private struct EditingDay: Identifiable {
    let index: Int
    var id: Int { index }
}
