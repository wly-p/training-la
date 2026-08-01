import DesignSystem
import SharedKernel
import SwiftUI
import TrainingDomain

/// 開練前預覽（13d + 14c）：卡片被點開後，開始訓練之前的最後一眼——這場要練什麼、重量怎麼來的、
/// 算不出來的那列老實說「待填」。這一步本身不落地任何東西（見 `TrainingHomeViewModel.previewPlan/previewRotation`），
/// 真正落地在「開始訓練」按下的那一刻。
struct TrainingPreviewSheet: View {
    let blueprint: PlannedWorkoutBlueprint
    /// 「和上次比」灰卡資料（14c）；nil＝查不到上一場，卡片不出現。
    var comparison: LastWorkoutComparison? = nil
    let onStart: () -> Void
    let onAdjustOnce: (() -> Void)?
    let onEditTemplate: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    private struct ExerciseRow: Identifiable {
        let id: UUID
        let name: String
        let equipment: Equipment
        let setCount: Int
        let representative: PlannedTargetSet?
    }

    private var rows: [ExerciseRow] {
        blueprint.exercises.map { exercise in
            let representative = blueprint.targets
                .filter { $0.exerciseId == exercise.exerciseId }
                .sorted { ($0.exerciseIndex, $0.setIndex) < ($1.exerciseIndex, $1.setIndex) }
                .first
            return ExerciseRow(
                id: exercise.exerciseId, name: exercise.name, equipment: exercise.equipment,
                setCount: exercise.setCount, representative: representative
            )
        }
    }

    private var totalSets: Int { blueprint.exercises.reduce(0) { $0 + $1.setCount } }

    /// 粗估時長：各組休息秒數（沒設當 90 秒）＋每組約 40 秒實作，換成分鐘。
    private var estimatedMinutes: Int {
        let restTotal = blueprint.targets.reduce(0) { $0 + ($1.restSec ?? 90) }
        let workTotal = blueprint.targets.count * 40
        return max(1, (restTotal + workTotal) / 60)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TLSpace.section) {
                header
                TLGroup {
                    ForEach(rows) { row in
                        exerciseRow(row)
                    }
                }
                localText("training.preview.hint")
                    .font(TLFont.zh(TLFont.rowSub, .regular))
                    .foregroundStyle(TLColor.neutral500)
                if let comparison {
                    vsLastCard(comparison)
                }
                actions
            }
            .padding(.horizontal, TLSpace.page)
            .padding(.top, TLSpace.section)
            .padding(.bottom, 40)
        }
        .background(TLColor.bg.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(TLRadius.container + 4)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TLSpace.gapS) {
            // kicker（14c）：循環/長期課表的週期定位；範本/自由訓練沒有這行。
            if let kicker = blueprint.kicker {
                Text(verbatim: kicker)
                    .font(TLFont.zh(TLFont.kicker, .semibold))
                    .tracking(TLFont.kickerTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(TLColor.accent700)
            }
            Text(verbatim: blueprint.name ?? String(localized: "training.todaysPlan", bundle: .module))
                .font(TLFont.zh(30, .bold))
                .foregroundStyle(TLColor.text)
            HStack(spacing: TLSpace.gapS) {
                if let pill = WeightSourceFormatting.intensityPillText(blueprint.intensityFactor) {
                    Text(String(format: String(localized: "training.preview.intensity %@", bundle: .module), pill))
                        .font(TLFont.zh(11.5, .semibold))
                        .foregroundStyle(TLColor.accent800)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(TLColor.accent200)
                        .clipShape(Capsule())
                }
                Text(verbatim: String(
                    format: String(localized: "training.preview.exerciseSetCountDuration %lld %lld %lld", bundle: .module),
                    blueprint.exercises.count, totalSets, estimatedMinutes
                ))
                .font(TLFont.zh(TLFont.rowSub, .regular))
                .foregroundStyle(TLColor.neutral600)
            }
        }
    }

    private func exerciseRow(_ row: ExerciseRow) -> some View {
        HStack(alignment: .center, spacing: TLSpace.gapM) {
            VStack(alignment: .leading, spacing: 3) {
                ExerciseNameWithEquipment(name: row.name, equipment: row.equipment.displayName)
                if let algebra = WeightSourceFormatting.algebraText(row.representative?.weightSource) {
                    Text(verbatim: algebra)
                        .font(TLFont.zh(11, .regular))
                        .foregroundStyle(TLColor.accent700)
                } else if let reason = WeightSourceFormatting.unresolvedReason(row.representative?.weightSource) {
                    Text(verbatim: reason)
                        .font(TLFont.zh(TLFont.rowSub, .regular))
                        .foregroundStyle(TLColor.neutral500)
                }
            }
            Spacer(minLength: TLSpace.gapS)
            trailingValue(row)
        }
        // 水平內距不可省——沒有它，列內文字會貼齊 TLGroup 邊緣被圓角切掉（bug1 破圖主因）。
        .padding(.horizontal, TLSpace.rowInset)
        .frame(minHeight: 62)
    }

    @ViewBuilder private func trailingValue(_ row: ExerciseRow) -> some View {
        if let weight = row.representative?.targetWeight {
            HStack(spacing: 4) {
                if let reps = row.representative?.targetReps {
                    Text(verbatim: "\(row.setCount) × \(reps)")
                        .font(TLFont.display(15))
                    Text(verbatim: "·").foregroundStyle(TLColor.neutral400)
                }
                Text(verbatim: "\(WeightDisplay.value(weight.value)) kg")
                    .font(TLFont.display(15))
            }
            .foregroundStyle(TLColor.text)
        } else {
            localText("training.preview.pending")
                .font(TLFont.zh(11.5, .semibold))
                .foregroundStyle(TLColor.neutral600)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(
                    Capsule().strokeBorder(TLColor.neutral400, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                )
        }
    }

    /// 「和上次比」灰卡（14c）：不是鼓勵語，是讓「開始」有依據——上次日期／達標組數／主項增減。
    private func vsLastCard(_ c: LastWorkoutComparison) -> some View {
        VStack(alignment: .leading, spacing: TLSpace.gapS) {
            localText("training.preview.vsLast")
                .font(TLFont.zh(TLFont.kicker, .semibold))
                .tracking(TLFont.kickerTracking)
                .textCase(.uppercase)
                .foregroundStyle(TLColor.neutral500)
            Text(verbatim: String(
                format: String(localized: "training.preview.vsLast.summary %@ %lld %lld", bundle: .module),
                "\(c.date.month)/\(c.date.day)", c.achievedSets, c.totalSets
            ))
            .font(TLFont.zh(TLFont.rowTitle, .medium))
            .foregroundStyle(TLColor.text)
            if let delta = c.mainLiftDeltaKg {
                Text(verbatim: String(
                    format: String(localized: "training.preview.vsLast.mainLift %@", bundle: .module),
                    mainLiftDeltaText(delta)
                ))
                .font(TLFont.zh(TLFont.rowSub, .semibold))
                .foregroundStyle(delta > 0 ? TLColor.accent700 : TLColor.neutral600)
            }
        }
        .padding(TLSpace.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TLColor.neutral300)
        .clipShape(RoundedRectangle(cornerRadius: TLRadius.inner, style: .continuous))
    }

    /// 主項增減文字：`+2.5 kg` / `−2.5 kg` / `持平`。
    private func mainLiftDeltaText(_ delta: Double) -> String {
        if delta == 0 { return String(localized: "training.preview.vsLast.same", bundle: .module) }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(WeightDisplay.value(abs(delta))) kg"
    }

    private var actions: some View {
        VStack(spacing: TLSpace.gapM) {
            localText("training.preview.lockNotice")
                .font(TLFont.zh(TLFont.rowSub, .regular))
                .foregroundStyle(TLColor.neutral500)
            Button(action: onStart) {
                localText("training.preview.start")
            }
            .buttonStyle(.tlPrimary)
            HStack(spacing: TLSpace.gapM) {
                if let onAdjustOnce {
                    Button {
                        dismiss()
                        onAdjustOnce()
                    } label: {
                        localText("training.preview.adjustOnce")
                    }
                    .buttonStyle(.tlSecondary)
                }
                if let onEditTemplate {
                    Button {
                        dismiss()
                        onEditTemplate()
                    } label: {
                        localText("training.preview.editTemplate")
                    }
                    .buttonStyle(.tlSecondary)
                }
            }
        }
    }
}
