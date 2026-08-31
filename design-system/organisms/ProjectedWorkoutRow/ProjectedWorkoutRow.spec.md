# ProjectedWorkoutRow

## 1 身分

| | |
|---|---|
| 層級 | L3 有機體 |
| 職責 | 課表某一天的一列 —— **長期課表投影出來、還沒落地**的訓練 |
| 原型 id | `12d` |
| 獨立使用 | **否 —— 必須置於 `TLGroup` 之內** |
| 容器責任 | 圓角、底色、分隔線由 `TLGroup` 負責 |
| 實作 | `Packages/Plan/Sources/PlanPresentation/Components/ProjectedWorkoutRow.swift` |
| Preview | `design-system/organisms/ProjectedWorkoutRow/ProjectedWorkoutRow.preview.html` |
| Preview CSS | 無自己的樣式 |

**組成**：`TLListRow`（L2）＋ `TLBadge`（L1）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `title` | `Text` | | 是 | — | 名稱 |
| `summary` | `Text` | | 是 | — | 副標＝組成摘要 |
| `addLabel` | `Text` | | 是 | — | 「加入這天」的文案 |
| `onAdd` | `() -> Void` | | 是 | — | 把投影變成真實排課 |

**Slots** — N/A
**事件** — `onAdd`

## 3 變體 variants

無。

## 4 狀態 states ★

<!-- states: default -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **整列不可點**，只有右側的「加入這天」可按 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | N/A |
| 內容極值 | 最短 / 最長 / 溢出 | 名稱與摘要一行截斷；右側按鈕不縮 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 「加入這天」在英文較長，是右欄寬度的決定因素 |

## 5 度量與行為

全部由 `TLListRow` 決定。

### 動態

無。

## 6 配色 ★

| 用途 | token |
|---|---|
| 圓章底／圖示 | `neutral-200` / `neutral-600` |
| 「加入這天」 | `accent-700` |

**圓章刻意是灰的** —— 這一列還不存在，用赭紅會讓它看起來已經排好了。

## 7 用法與禁用法

**用它**：長期課表投影到某一天、但還沒落地的建議。

**易混淆**：`PlanWorkoutRow` —— 那個是**已經存在**的排課：圓章是序號或勾、整列可點。
判準：這一筆已經存在了嗎？

**不要用它**：
- 讓整列可點 —— 這一列還不是真的排課，不該點哪裡都觸發落地
- 用序號圓章 —— 它還沒有序，落地之後才有

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 從 `PlanScheduleView` 抽出成 L3 | 階段 4 的分層落地 |
| 2026-08-31 | **驗證結果：純由 L2／L1 組成，零缺口** | |
