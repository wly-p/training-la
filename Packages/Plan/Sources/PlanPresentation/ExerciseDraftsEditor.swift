import PlanDomain
import SharedKernel
import SwiftUI

/// 動作目標編輯區塊（排課表單與課表範本表單共用）。
/// `readOnly` 時所有控制項 disabled、隱藏「加入動作」與刪除。
struct ExerciseDraftsEditor: View {
    @Binding var drafts: [ExerciseTargetDraft]
    let catalog: [PlanCatalogExercise]
    var readOnly: Bool = false

    @State private var showsPicker = false

    var body: some View {
        Section {
            ForEach($drafts) { $draft in
                draftRow($draft)
            }
            .onDelete(perform: readOnly ? nil : { drafts.remove(atOffsets: $0) })
            .onMove(perform: readOnly ? nil : { drafts.move(fromOffsets: $0, toOffset: $1) })

            if !readOnly {
                Button {
                    showsPicker = true
                } label: {
                    Label { localText("plan.addExercise") } icon: { Image(systemName: "plus") }
                }
                // sheet 掛在 Button（一般 view）上才會可靠彈出；掛在 Section 上在 Form 內不會present。
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
        } header: {
            HStack {
                localText("plan.exercises")
                // 兩個以上動作才需要排序；EditButton 進入編輯模式後出現拖拉握把。
                #if os(iOS)
                if !readOnly && drafts.count > 1 {
                    Spacer()
                    EditButton()
                        .textCase(nil)   // header 預設大寫，EditButton 文字不套用
                }
                #endif
            }
        }
        .disabled(readOnly)
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
                // 「×」無需翻譯（verbatim），避免被隱式當 LocalizedStringKey 抽進 String Catalog。
                Text(verbatim: "×")
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

/// 把 PlanWorkout / WorkoutTemplate 的 blocks 轉成表單用的 drafts。
func draftsFromBlocks(_ blocks: [PlanBlock]) -> [ExerciseTargetDraft] {
    blocks.map { block in
        let first = block.sets[0]
        return ExerciseTargetDraft(
            exerciseId: block.exerciseId,
            setCount: block.sets.count,
            targetWeight: first.targetWeight,
            targetReps: first.targetReps,
            restSec: first.restSec
        )
    }
}
