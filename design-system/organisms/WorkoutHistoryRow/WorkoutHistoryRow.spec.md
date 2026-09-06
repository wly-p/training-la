# WorkoutHistoryRow

## 1 身分

| | |
|---|---|
| 層級 | L3 有機體 |
| 職責 | 歷史清單（依日期）的一列 |
| 原型 id | `7b` |
| 獨立使用 | **否 —— 必須置於 `TLGroup` 之內** |
| 容器責任 | 圓角、底色、分隔線由 `TLGroup` 負責 |
| 實作 | `Packages/History/Sources/HistoryPresentation/Components/WorkoutHistoryRow.swift` |
| Preview | `design-system/organisms/WorkoutHistoryRow/WorkoutHistoryRow.preview.html` |
| Preview CSS | `components.preview.css` §WorkoutHistoryRow |

**組成**：`TLListRow`（L2）。左件的日期柱是這個 L3 自己的排法。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `day` | `String` | | 是 | — | 日數 |
| `weekday` | `String` | | 是 | — | 星期縮寫 |
| `title` | `Text` | | 是 | — | 名稱（沒取名時由呼叫端給 fallback） |
| `summary` | `Text` | | 是 | — | 副標＝組成摘要 |

**Slots** — N/A
**事件** — 無（drill-in 由呼叫端包 `NavigationLink`）

## 3 變體 variants

無。

## 4 狀態 states ★

<!-- states: default -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | 按下態由外層的 `NavigationLink` 給 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | N/A |
| 內容極值 | 最短 / 最長 / 溢出 | 名稱與摘要一行截斷；**日期柱固定寬不縮** |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 星期縮寫在英文是三個字母，比中文寬 —— 日期柱的寬度由它決定 |

## 5 度量與行為

| | |
|---|---|
| 日期柱寬 | `size.dateColumn` |
| 日數與星期之間 | `space.dateStackGap`（刻意極窄，兩行要讀成一個東西） |
| 其餘 | 由 `TLListRow` 決定 |

**固定寬是為了讓整個月的日期左緣對齊** —— 寬度跟著內容走的話，
10 號與 9 號那兩列就會差一個字寬。

⚠ 全 app 的「列首固定欄」有**三種寬度**：`40`（這個）、`44`（逐組列的組序）、
`48`（範本編輯的組序）。後兩者是**同一個角色的兩個值**，待設計端收斂。

### 動態

無自己的轉場。

## 6 配色 ★

| 用途 | token |
|---|---|
| 日數 | `textPrimary` |
| 星期 | `neutral-500` |

## 7 用法與禁用法

**用它**：歷史清單的「依日期」模式。

**易混淆**：`ExerciseRow` —— 那個右側是分類標籤、左側沒有東西；
這個左側是日期柱。

**不要用它**：
- 「依動作」模式 —— 那一列左側是肌群圓章，用 `TLListRow` ＋ `TLBadge` 直接組
- 把時長放進日期柱 —— 那一柱只承載「哪一天」

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 從 `HistoryView` 抽出成 L3 | 階段 3 的分層落地 |
| 2026-08-31 | **日期柱的 `9.5` 與 `display(19)` 原樣搬進來** | 前者低於可讀下限（設計端已判定要連同 `kicker` 一起檢視）、後者屬於 display 尺度第二批。**搬進元件不等於解決**，但它們現在有地址了 |
