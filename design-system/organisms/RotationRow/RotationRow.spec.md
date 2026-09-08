# RotationRow

## 1 身分

| | |
|---|---|
| 層級 | L3 有機體 |
| 職責 | 循環清單的一列 |
| 原型 id | `8b` |
| 獨立使用 | **否 —— 必須置於 `TLGroup` 之內** |
| 容器責任 | 圓角、底色、分隔線由 `TLGroup` 負責 |
| 實作 | `Packages/Plan/Sources/PlanPresentation/Components/RotationRow.swift` |
| Preview | `design-system/organisms/RotationRow/RotationRow.preview.html` |
| Preview CSS | 無自己的樣式（見 `components.preview.css` 的說明段） |

**組成**：`TLSwipeToRevealRow`（控制項）＋ `TLListRow`（L2）＋ `TLBadge`（L1）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `mode` | `Mode` | `active` / `inactive` | 是 | — | 兩種形態，差別不只是顏色，見第 3 節 |
| `id` | `UUID` | | 是 | — | drill-in 的目的地。**只有 `active` 用得到** |
| `name` | `String` | | 是 | — | 循環名 |
| `subtitle` | `Text` | | 是 | — | 副標＝組成摘要 |
| `trailing` | `AnyView` | | 是 | — | 右側內容：啟用態是進度膠囊、未啟用態是「啟用」鈕。**由呼叫端給** —— 它才知道文案與行為 |
| `deactivateLabel` | `Text` | | 是 | — | 左滑露出的「停用」文案 |
| `onDeactivate` | `() -> Void` | | 是 | — | 左滑停用 |
| `menu` | `AnyView` | | 是 | — | 長按選單。兩種形態都有 |

**Slots** — N/A（`trailing`／`menu` 是 `AnyView` 而不是 `@ViewBuilder`，見第 8 節）
**事件** — `onDeactivate`

## 3 變體 variants

| 變體 | 說明 |
|---|---|
| `active` 啟用 | 可 drill-in（有 chevron）、圓章是赭紅、右側是進度膠囊、左滑可停用 |
| `inactive` 未啟用 | **不 drill-in**（設計稿無 chevron）、圓章是灰、右側是 inline「啟用」鈕、不能左滑 |

**未啟用為什麼不 drill-in**：編輯未啟用的循環是低頻操作，路徑是「先啟用再進去」。
留一個點得下去卻只是看的入口，會讓「啟用」那顆鈕看起來可有可無。

## 4 狀態 states ★

<!-- states: active, inactive, swiped -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | `active` 可點（按下態由 `TLListRow` 給）、`inactive` 整列不可點但右側鈕可點、`swiped` 只有 `active` 有。沒有 disabled —— 未啟用是一種形態不是停用 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | N/A |
| 內容極值 | 最短 / 最長 / 溢出 | 名稱與摘要一行截斷；圓章與右側不縮 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 右側的「啟用」在英文較長，是右欄寬度的決定因素 |

## 5 度量與行為

全部由 `TLListRow` 決定。左滑露出的動作寬 88pt。

### 文字與溢出

名稱一行截斷；摘要一行截斷。

### 動態

左滑 `motion.base` easeOut。

## 6 配色 ★

| 用途 | `active` | `inactive` |
|---|---|---|
| 圓章底 | `actionPrimary` | `neutral-300` |
| 圓章圖示 | `surfaceBase` | `neutral-600` |

**左滑的「停用」是 `neutral-400` 不是紅的** —— 停用可以再啟用，它不是破壞性操作。
紅色留給真的刪掉的東西。

## 7 用法與禁用法

**用它**：循環清單。

**易混淆**：`ProgramRow` —— 那個的啟用態是**一張卡**不是一列（多了進度區），
而這個兩種形態都是列。判準：啟用後要不要顯示進度？要就是 `ProgramRow`。

**不要用它**：
- 給 `inactive` 傳有意義的 `id` 期待它能點 —— 未啟用刻意不 drill-in
- 把「啟用」鈕做成整列可點 —— 那會跟 drill-in 撞在一起

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 從 `RotationListView` 抽出成 L3 | 階段 2 的分層落地 |
| 2026-08-31 | **驗證結果：純由 L2／L1 組成，零缺口** | 兩種形態都只是 `TLListRow` 換填法 |
| 2026-08-31 | **記錄 `trailing`／`menu` 用 `AnyView` 的代價** | 它們是 stored property 不是 `@ViewBuilder`，所以型別被抹掉、SwiftUI 少了一次 diff 的機會。改成泛型 slot 會讓這個型別長出兩個泛型參數；目前清單短，先留著。**若循環清單日後變長，這是第一個要看的地方** |
