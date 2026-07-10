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
                    TextField("名稱（例：推日）", text: $name)
                    Toggle("指定日期", isOn: $hasDate)
                    if hasDate {
                        DatePicker("日期", selection: $date, displayedComponents: .date)
                    } else {
                        Text("循環課表：依順序輪替，不綁定日期")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("動作") {
                    ForEach($drafts) { $draft in
                        draftRow($draft)
                    }
                    .onDelete { drafts.remove(atOffsets: $0) }

                    Button {
                        showsPicker = true
                    } label: {
                        Label("加入動作", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(isCreating ? "新增排課" : "編輯排課")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        Task {
                            let day = hasDate ? DayDate(date) : nil
                            await onSubmit(name.isEmpty ? nil : name, day, drafts)
                            dismiss()
                        }
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
            Text(name(for: draft.wrappedValue.exerciseId)).font(.headline)
            Stepper("組數：\(draft.wrappedValue.setCount)", value: draft.setCount, in: 1...20)
            HStack {
                Text("目標")
                TextField("重量", value: Binding(
                    get: { draft.wrappedValue.targetWeight?.value ?? 0 },
                    set: { draft.wrappedValue.targetWeight = Weight(value: $0, unit: draft.wrappedValue.targetWeight?.unit ?? .kg) }
                ), format: .number)
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
                TextField("次數", value: Binding(
                    get: { draft.wrappedValue.targetReps ?? 0 },
                    set: { draft.wrappedValue.targetReps = $0 }
                ), format: .number)
                .frame(width: 44)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            }
            .font(.subheadline)
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
                        Text(exercise.name)
                        Spacer()
                        Text(exercise.muscleGroup.displayName)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "搜尋動作")
            .navigationTitle("加入動作")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .overlay {
                if catalog.isEmpty {
                    ContentUnavailableView("動作庫是空的", systemImage: "books.vertical",
                                           description: Text("先到動作庫建立動作"))
                }
            }
        }
    }
}
