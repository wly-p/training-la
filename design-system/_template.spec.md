# <元件名>

> 規格樣板。十二節，標 ★ 的可機器驗。
> L1 原子通常沒有第 2 節的 slots、也沒有第 11 節；其餘各節都要填。
> **不適用的項目寫 `N/A` 並附理由，不要刪掉標題** —— 省略正是狀態遺失的方式。

## 1 身分

| | |
|---|---|
| 層級 | L1 原子 / L2 分子 / L3 有機體 |
| 職責 | 一句話 |
| 原型 id | `4c` / `13a` …（沿用設計文件的 id） |
| 實作 | `Packages/…/X.swift` |
| Preview | `design-system/…/X.preview.html` |

## 2 介面 ★

**Props**

| 名稱 | 型別 | 必填 | 預設 | 說明 |
|---|---|---|---|---|

**Slots** — 可插入的子內容（SwiftUI 的 `@ViewBuilder`）
**事件** — `onTap` / `onChange` …

> 這節決定「應用層只能排列堆疊」是否可能。props 不夠，應用層就會被迫硬編。
> 也是判斷「元件庫夠不夠用」的唯一依據。

## 3 變體 variants

互斥的樣式選擇。

## 4 狀態 states ★

<!-- states: default -->

上面那行是**機器讀的**：列出這個元件實際具備的狀態，`preview.html` 必須每個都有
對應的 `data-state="…"`。下面的表格是給人讀的，逐項回答，不適用寫 `N/A` ＋ 理由。

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | |
| 選取 | selected / unselected / indeterminate | |
| 資料 | empty / loading / error | |
| 內容極值 | 最短 / 最長 / 溢出 / 數字最大位數 | |
| 主題 | light / dark | |
| 語言 | 中文 / 英文（字級 ×1.08） | |

## 5 度量

全部寫 token 名，不寫數字。

## 6 配色 ★

只列語意 token，不出現任何 hex。

## 7 文字行為

溢出處理 / 多語系寬度 / Dynamic Type 行為（現在不實作，位置先寫）。

## 8 動態

轉場 / 動畫時長與曲線 / 觸覺回饋。

## 9 無障礙

accessibility label / trait、最小觸控 44pt、`accessibilityIdentifier` 慣例。

## 10 用法與禁用法

何時用這個而不是那個。明確禁止項。

## 11 組成 ★

（L2 / L3 才有）由哪些下層元件組成。

## 12 變更紀錄

偏離設計稿時記這裡，含原因。
