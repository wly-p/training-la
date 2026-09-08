# TemplateRow

## 1 身分

| | |
|---|---|
| 層級 | L3 有機體 |
| 職責 | 範本清單的一列 |
| 原型 id | `5b` |
| 獨立使用 | **否 —— 必須置於 `TLGroup` 之內** |
| 容器責任 | 圓角、底色、分隔線由 `TLGroup` 負責 |
| 實作 | `Packages/Plan/Sources/PlanPresentation/Components/TemplateRow.swift` |
| Preview | `design-system/organisms/TemplateRow/TemplateRow.preview.html` |
| Preview CSS | 無自己的樣式（見 `components.preview.css` 的說明段） |

**組成**：`TLSwipeToRevealRow`（控制項）＋ `TLListRow`（L2）＋ `TLBadge`（L1）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `name` | `String` | | 是 | — | 範本名 |
| `summary` | `Text` | | 是 | — | 副標＝組成摘要（這份範本含哪些動作）。階層關係唯一的傳達管道 |
| `blockCount` | `Int` | | 是 | — | 圓章裡的數字＝含幾個動作 |
| `duplicateLabel` | `Text` | | 是 | — | 左滑露出的「複製」文案 |
| `deleteLabel` | `Text` | | 是 | — | 長按選單的「刪除」文案 |
| `onDuplicate` | `() -> Void` | | 是 | — | 左滑複製 |
| `onDelete` | `() -> Void` | | 是 | — | 選單刪除 |
| `onTap` | `() -> Void` | | 是 | — | 點整列進編輯 |

**Slots** — N/A
**事件** — `onDuplicate` / `onDelete` / `onTap`

**兩個操作入口對應不同頻率**：左滑露出複製（常用、單手可及）、長按出刪除（低頻、需要更明確的意圖）。

## 3 變體 variants

無。每一列長得一樣。

## 4 狀態 states ★

<!-- states: default, swiped -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | default、pressed（由 `TLListRow` 給）、swiped（左滑露出動作）。沒有 disabled —— 範本沒有「不能編輯」的狀態 |
| 選取 | selected / unselected / indeterminate | N/A —— 範本清單不做選取 |
| 資料 | empty / loading / error | N/A —— 空清單是 `TLInlineEmptyState` 的事，不是這一列的 |
| 內容極值 | 最短 / 最長 / 溢出 | 名稱與摘要各自一行截斷；圓章不縮 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 摘要是全 app 中英落差最大的文字（一串名稱的連接） |

## 5 度量與行為

全部由 `TLListRow` 決定（列高 `size.rowWithSub`、內距 `space.rowInset`）。
左滑露出的動作寬 88pt，由 `TLSwipeToRevealRow` 決定。

### 文字與溢出

名稱一行截斷；摘要一行截斷。

### 動態

左滑：`motion.base` easeOut。按下態由 `TLListRow` 提供。

## 6 配色 ★

| 用途 | token |
|---|---|
| 圓章底／字 | `neutral-300` / `neutral-800` |

**圓章刻意是 neutral 不是 accent** —— 那個數字是「含幾個動作」，是資訊不是狀態。
赭紅保留給進行中的東西（見 `RotationRow`／`ProgramRow`）。

## 7 用法與禁用法

**用它**：範本清單。

**易混淆**：`ExerciseRow`（動作列）—— 那個右側是分類標籤、沒有圓章；
這個左側有數字圓章、副標是組成摘要。

**不要用它**：
- 顯示循環或長期課表 —— 那兩個有進行中／未啟用兩種形態，這個沒有
- 把狀態放進 `summary` —— 副標是組成摘要，狀態一律放右側

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 從 `TemplateListView` 抽出成 L3 | 階段 2 的分層落地 |
| 2026-08-31 | **驗證結果：純由 L2／L1 組成，但撞到一個介面缺口** | `TLBadge(count:)` 把顏色寫死 sage，而同一個檔裡的 `init(icon:fill:tint:)` 早就把顏色開成 prop。需要 neutral 圓章的這一列只能繞過便利建構子手工建。**介面不一致本身就是缺口** —— 已把 `fill`／`tint` 補進 `init(count:)` |
