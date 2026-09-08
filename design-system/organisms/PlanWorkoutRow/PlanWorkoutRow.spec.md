# PlanWorkoutRow

## 1 身分

| | |
|---|---|
| 層級 | L3 有機體 |
| 職責 | 課表某一天的一列 —— **已經排定**的訓練 |
| 原型 id | `12c` |
| 獨立使用 | **否 —— 必須置於 `TLGroup` 之內** |
| 容器責任 | 圓角、底色、分隔線由 `TLGroup` 負責 |
| 實作 | `Packages/Plan/Sources/PlanPresentation/Components/PlanWorkoutRow.swift` |
| Preview | `design-system/organisms/PlanWorkoutRow/PlanWorkoutRow.preview.html` |
| Preview CSS | 無自己的樣式 |

**組成**：`TLListRow`（L2）＋ `TLBadge`（L1）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `title` | `Text` | | 是 | — | 名稱（沒取名時由呼叫端給 fallback） |
| `summary` | `Text` | | 是 | — | 副標＝組成摘要 |
| `orderIndex` | `Int` | | 是 | — | 第幾項（從 0 起算，顯示時 +1） |
| `isDone` | `Bool` | | 是 | — | 完成後圓章換成勾 |
| `onTap` | `() -> Void` | | 是 | — | 點整列開表單 |

**Slots** — N/A
**事件** — `onTap`

## 3 變體 variants

無變體，但圓章有兩種內容：

| `isDone` | 圓章 |
|---|---|
| `false` | 序號（`neutral-300` 底、`neutral-700` 字） |
| `true` | 勾（`actionPrimary` 底、`surfaceBase` 勾） |

**兩種狀態共用同一顆圓章是刻意的** —— 那一格回答的永遠是「這一項的進度」，
不是有時候回答順序、有時候回答狀態。

## 4 狀態 states ★

<!-- states: pending, done -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | 可點（按下態由 `TLListRow` 給）。**完成的也可點** —— 進去是唯讀檢視 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | N/A —— 空的那一天是 `emptyDay` 的事 |
| 內容極值 | 最短 / 最長 / 溢出 | 名稱與摘要一行截斷；圓章不縮 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 摘要是中英落差最大的文字 |

## 5 度量與行為

全部由 `TLListRow` 決定（`size.rowWithSub`、`space.rowInset`）。

### 動態

無自己的轉場。

## 6 配色 ★

見第 3 節。

## 7 用法與禁用法

**用它**：課表某一天的已排定清單。

**易混淆**：`ProjectedWorkoutRow` —— 那個是**還沒落地**的投影建議：圓章是行事曆圖示、
整列不可點、右側有「加入這天」。判準：這一筆已經存在了嗎？

**不要用它**：
- 顯示投影建議 —— 那會讓「還沒落地」看起來像已經排好了
- 用圓章表達別的東西 —— 它只回答進度

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 從 `PlanScheduleView` 抽出成 L3 | 階段 4 的分層落地 |
| 2026-08-31 | 圓章裡的勾 `13` 改成 `icon.inline`(14) | 元件內部的字面值也是字面值。+1px |
| 2026-08-31 | **驗證結果：純由 L2／L1 組成，零缺口** | 序號的 `display(15)` 留在元件內部等第二批 |
