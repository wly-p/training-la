import PlanDomain
import SharedKernel
import SwiftUI

struct PlanWorkoutFormView: View {
    let target: PlanFormTarget
    let catalog: [PlanCatalogExercise]
    let onSubmit: (String?, DayDate?, [ExerciseTargetDraft]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var drafts: [ExerciseTargetDraft]
    @State private var showsPicker = false

    init(
        target: PlanFormTarget,
        catalog: [PlanCatalogExercise],
        onSubmit: @escaping (String?, DayDate?, [ExerciseTargetDraft]) async -> Void
    ) {
        self.target = target
        self.catalog = catalog
        self.onSubmit = onSubmit
        switch target {
        case .create:
            _name = State(initialValue: "")
            _hasDate = State(initialValue: false)
            _date = State(initialValue: Date())
            _drafts = State(initialValue: [])
        case .edit(let plan):
            _name = State(initialValue: plan.name ?? "")
            _hasDate = State(initialValue: plan.date != nil)
            _date = State(initialValue: plan.date?.asDate ?? Date())
            _drafts = State(initialValue: plan.blocks.map { block in
                let first = block.sets[0]
                return ExerciseTargetDraft(
                    exerciseId: block.exerciseId,
                    setCount: block.sets.count,
                    targetWeight: first.targetWeight,
                    targetReps: first.targetReps,
                    restSec: first.restSec
                )
            })
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("", text: $name, prompt: localText("plan.name.placeholder"))
                    Toggle(isOn: $hasDate) { localText("plan.specificDate") }
                    if hasDate {
                        DatePicker(selection: $date, displayedComponents: .date) {
                            localText("plan.date")
                        }
                    } else {
                        localText("plan.recurring.hint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach($drafts) { $draft in
                        draftRow($draft)
                    }
                    .onDelete { drafts.remove(atOffsets: $0) }

                    Button {
                        showsPicker = true
                    } label: {
                        Label { localText("plan.addExercise") } icon: { Image(systemName: "plus") }
                    }
                } header: {
                    localText("plan.exercises")
                }
            }
            .navigationTitle(isCreating ? localText("plan.new") : localText("plan.edit"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("plan.cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let day = hasDate ? DayDate(date) : nil
                            await onSubmit(name.isEmpty ? nil : name, day, drafts)
                            dismiss()
                        }
                    } label: {
                        localText("plan.save")
                    }
                    .disabled(drafts.isEmpty)
                }
            }
            .sheet(isPresented: $showsPicker) {
                PlanExercisePickerView(catalog: catalog) { exercise in
                    drafts.append(ExerciseTargetDraft(
                        exerciseId: exercise.id,
                        setCount: 3,
                        targetWeight: Weight(value: 20, unit: .kg),
                        targetReps: 8
                    ))
                }
            }
        }
    }

    private func draftRow(_ draft: Binding<ExerciseTargetDraft>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 動作名是 DB 資料（verbatim）
            Text(verbatim: name(for: draft.wrappedValue.exerciseId)).font(.headline)
            Stepper(value: draft.setCount, in: 1...20) {
                localText("plan.setCount \(draft.wrappedValue.setCount)")
            }
            HStack {
                localText("plan.target")
                TextField("", value: Binding(
                    get: { draft.wrappedValue.targetWeight?.value ?? 0 },
                    set: { draft.wrappedValue.targetWeight = Weight(value: $0, unit: draft.wrappedValue.targetWeight?.unit ?? .kg) }
                ), format: .number, prompt: localText("plan.weight"))
                .frame(width: 60)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                Picker("", selection: Binding(
                    get: { draft.wrappedValue.targetWeight?.unit ?? .kg },
                    set: { draft.wrappedValue.targetWeight = Weight(value: draft.wrappedValue.targetWeight?.value ?? 0, unit: $0) }
                )) {
                    ForEach(WeightUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                Text("×")
                TextField("", value: Binding(
                    get: { draft.wrappedValue.targetReps ?? 0 },
                    set: { draft.wrappedValue.targetReps = $0 }
                ), format: .number, prompt: localText("plan.reps"))
                .frame(width: 44)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            }
            .font(.subheadline)

            HStack {
                localText("plan.rest")
                TextField("", text: Binding(
                    get: { draft.wrappedValue.restSec.map(String.init) ?? "" },
                    set: {
                        let n = Int($0.trimmingCharacters(in: .whitespaces))
                        draft.wrappedValue.restSec = (n ?? 0) > 0 ? n : nil
                    }
                ), prompt: localText("plan.sec.optional"))
                .frame(width: 70)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                localText("plan.sec")
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func name(for id: UUID) -> String {
        catalog.first { $0.id == id }?.name ?? "動作"
    }

    private var isCreating: Bool {
        if case .create = target { return true }
        return false
    }
}

private struct PlanExercisePickerView: View {
    let catalog: [PlanCatalogExercise]
    let onSelect: (PlanCatalogExercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var visible: [PlanCatalogExercise] {
        guard !searchText.isEmpty else { return catalog }
        return catalog.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(visible) { exercise in
                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    HStack {
                        // 動作名與肌群都是 DB / enum 資料（verbatim）
                        Text(verbatim: exercise.name)
                        Spacer()
                        Text(verbatim: exercise.muscleGroup.displayName)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: localText("plan.searchExercises"))
            .navigationTitle(localText("plan.addExercise"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { localText("plan.cancel") }
                }
            }
            .overlay {
                if catalog.isEmpty {
                    ContentUnavailableView {
                        Label { localText("plan.emptyLibrary") } icon: { Image(systemName: "books.vertical") }
                    } description: {
                        localText("plan.emptyLibrary.hint")
                    }
                }
            }
        }
    }
}
