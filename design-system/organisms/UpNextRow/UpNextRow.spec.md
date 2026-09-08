# UpNextRow

## 1 身分

| | |
|---|---|
| 層級 | L3 有機體 |
| 職責 | 訓練中「接下來」的一列 |
| 原型 id | `11c` |
| 獨立使用 | 是 —— **刻意不套 `TLGroup`**，見第 7 節 |
| 容器責任 | 列與列之間的細線由「接下來」區段畫 |
| 實作 | `Packages/Training/Sources/TrainingPresentation/Components/UpNextRow.swift` |
| Preview | `design-system/organisms/UpNextRow/UpNextRow.preview.html` |
| Preview CSS | 無自己的樣式 |

**組成**：不由 `TL*` 元件組成（純文字兩欄）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `name` | `String` | | 是 | — | 動作名 |
| `isCurrent` | `Bool` | | 是 | — | 目前這個動作 → 名稱加粗 |
| `target` | `String?` | | 是 | — | 右側目標「3 × 10 · 24 kg」。自由加練沒有課表目標＝`nil`。**呼叫端算好** |
| `onSelect` | `() -> Void` | | 是 | — | 點列＝切到那個動作 |
| `onLongPress` | `() -> Void` | | 是 | — | 長按＝開中途改課 |

**Slots** — N/A
**事件** — `onSelect` / `onLongPress`

## 3 變體 variants

無。`isCurrent` 只改字重。

## 4 狀態 states ★

<!-- states: normal, current, noTarget -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | 可點、可長按。**沒有按下態的底色** —— 它沒有卡片底，加底色會變成另一種元件 |
| 選取 | selected / unselected / indeterminate | `isCurrent` 是「現在在做的」，不是選取 |
| 資料 | empty / loading / error | N/A |
| 內容極值 | 最短 / 最長 / 溢出 | 動作名長時擠壓右側目標；目標不換行 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 動作名隨語言換 |

## 5 度量與行為

| | |
|---|---|
| 上下內距 | `space.fieldPadV` |
| 名稱與目標之間 | 最小 `space.gapS`（中間彈性） |
| 長按門檻 | 0.4 秒 |

### 動態

無。

## 6 配色 ★

| 用途 | token |
|---|---|
| 名稱 | `textPrimary` |
| 目標 | `neutral-500` |

## 7 用法與禁用法

**用它**：訓練中的「接下來」清單。

**易混淆**：`TLListRow` —— 那個有卡片底、有 chevron、是資料清單的列。
這個**刻意不套 `TLGroup`**：設計稿是直接排在頁面底色上、只用細線分隔 ——
卡片底會讓它看起來跟上面的組表同一個層級，但它只是待辦清單。

**不要用它**：
- 套進 `TLGroup` —— 見上
- 自己算右側目標 —— 那要讀 blueprint，屬於呼叫端

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-09-04 | 從 `ActiveWorkoutView` 抽出成 L3 | 階段 5 的分層落地 |
| 2026-09-04 | 右側目標的 `display(13.5)` 原樣搬進來 | display 尺度還沒收斂（第二批），搬進元件不等於解決，但它現在有地址了 |
