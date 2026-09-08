# SetTableRow

## 1 身分

| | |
|---|---|
| 層級 | L3 有機體 |
| 職責 | 訓練中的組表一列（組／目標／實際三欄） |
| 原型 id | `11c` |
| 獨立使用 | 是（自成一顆圓角列，不進 `TLGroup`） |
| 容器責任 | 列與列之間的間距由組表給 |
| 實作 | `Packages/Training/Sources/TrainingPresentation/Components/SetTableRow.swift` |
| Preview | `design-system/organisms/SetTableRow/SetTableRow.preview.html` |
| Preview CSS | `components.preview.css` §SetTableRow |

**組成**：`TLCard`（L2，`radius: .inner`）＋ 同檔的 `SetTableColumns`（欄位排版）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `row` | `SetTableRow` | | 是 | — | 這一組的資料（序號／目標／實際／狀態） |
| `weightUnit` | `WeightUnit` | `kg` / `lb` | 是 | — | 顯示單位。**元件不做換算判斷**，只照傳進來的單位格式化 |
| `isUndoable` | `Bool` | | 是 | — | 只有剛記錄的那一組能撤銷 —— **由呼叫端算**，元件不問 view model |
| `currentSetLabel` | `Text` | | 是 | — | 「現在這組」的文案 |
| `undoLabel` | `Text` | | 是 | — | 撤銷鍵的無障礙文案 |
| `onUndo` | `() -> Void` | | 是 | — | 撤銷上一組 |

**Slots** — N/A
**事件** — `onUndo`

## 3 變體 variants

無變體，但**三種狀態同一個排版，差別在每一欄放什麼**：

| 狀態 | 組欄 | 目標欄 | 實際欄 |
|---|---|---|---|
| `done` | 赭紅實心圓＋白勾 | 目標值 | 實際值 ＋（可撤銷時）↩ |
| `current` | 反白圓章＋序號 | 目標值（粗體、accent） | 「現在這組」 |
| `upcoming` | 淡色序號 | 目標值 | `—` |

## 4 狀態 states ★

<!-- states: done, current, upcoming -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **整列不可點** —— 只有 ↩ 可按。點列沒有意義，而且會誤觸撤銷 |
| 選取 | selected / unselected / indeterminate | `current` 不是選取，是進度 |
| 資料 | empty / loading / error | N/A —— 沒有組就不會有這一列 |
| 內容極值 | 最短 / 最長 / 溢出 | 數字用 `monospacedDigit` 對齊；欄寬固定，兩位數組序放得下 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 「現在這組」在英文較長，是實際欄的寬度決定因素 |

## 5 度量與行為

| | |
|---|---|
| 組欄寬 | `size.setIndexColumnNarrow`（28，留給兩位數） |
| 三欄間距 | `space.setColumnGap` |
| 圓章 | `size.setBadge` |
| 卡 | `TLCard(radius: .inner)`，`current` 用深底 |
| 未做的列 | 整列 0.6 透明 |

### 兩個 0 尺寸的測試錨點

`done` 與 `current` 各有一個 **0×0、字級 1、透明**的節點，帶 `accessibilityIdentifier`。
表格視覺上不畫「第 N 組」（那是打勾圖示），但 UITest 要數得出「記了幾組」與「停在第幾組」。

**那裡的 1 與 0 不是設計值，是「看不見」的寫法**，所以刻意不吃 token。

### 動態

無轉場。狀態改變時直接換。

## 6 配色 ★

| 用途 | token |
|---|---|
| `current` 底 | `surfaceInput`（借用，見 `TLCard` 規格第 6 節） |
| 其餘底 | `surfaceRaised` |
| `current` 目標值 | `accent-800` |
| 一般目標值 | `neutral-600` |
| ↩ | `accent-700`（**換掉系統藍**，配色一致） |

## 7 用法與禁用法

**用它**：訓練中的組表。

**易混淆**：`PlanWorkoutRow` —— 那是「某一天要做哪些訓練」；這是「這個動作的第幾組」。

**不要用它**：
- 讓整列可點 —— 一碰列就誤撤銷（實測過的 bug）
- 自己算「能不能撤銷」 —— 那是 session 狀態，屬於呼叫端

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-09-04 | 從 `ActiveWorkoutView` 抽出成 L3 | 那個檔自己組了 26 個 view，這一組（列 ＋ 三欄 ＋ 欄位排版）佔 5 個 |
| 2026-09-04 | `SetTableColumns` 一起搬出來 | 表頭與資料列共用它 —— 兩邊各寫一次的話欄寬遲早對不齊 |
| 2026-09-04 | 欄寬 `28` 與欄距 `12` 改吃 token | ⚠ 全 app 的「列首固定欄」已有 28／40／44／48／60 五種寬度，待設計端收斂 |
