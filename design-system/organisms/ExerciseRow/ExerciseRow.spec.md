# ExerciseRow

## 1 身分

| | |
|---|---|
| 層級 | L3 有機體 |
| 職責 | 動作清單的一列 |
| 原型 id | `4c` `18b` |
| 獨立使用 | **否 —— 必須置於 `TLGroup` 之內** |
| 容器責任 | 圓角、底色、分隔線由 `TLGroup` 負責 |
| 實作 | `Packages/Spec/Sources/SpecPresentation/Components/ExerciseRow.swift` |
| Preview | `design-system/organisms/ExerciseRow/ExerciseRow.preview.html` |
| Preview CSS | `components.preview.css` §ExerciseRow |

**組成**：`TLListRow`（L2）＋ `TLEquipmentTag`（L2）

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `name` | `String` | | 是 | — | 動作名 |
| `isOfficial` | `Bool` | | 是 | — | 內建動作唯讀，見第 3 節 |
| `tailLabel` | `String` | | 是 | — | 尾欄文字。**呼叫端決定顯示肌群還是器材**（它才知道目前分組） |
| `tailIdentifier` | `String` | `muscleTag` / `equipmentTag` | 是 | — | 尾欄的測試定位鍵 |
| `deleteLabel` | `Text` | | 是 | — | 刪除選單的文案 |
| `onEdit` | `() -> Void` | | 是 | — | 點列進編輯 |
| `onDelete` | `() -> Void` | | 是 | — | 選單刪除 |

**Slots** — N/A
**事件** — `onEdit` / `onDelete`

## 3 變體 variants

| 變體 | 說明 |
|---|---|
| 使用者自建 | 可點進編輯、有 chevron、長按可刪 |
| 內建（official） | **唯讀**：不進編輯、沒有刪除選單、**也沒有 chevron** |

**為什麼內建的不顯示 chevron**：留著箭頭卻點不動比沒有箭頭更難懂。
而且刪除選單是整個 modifier 拿掉、不是留一個空的 —— 空 menu 長按仍會有抬起動畫卻沒有選項。

## 4 狀態 states ★

<!-- states: editable, official -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | 自建列可點（按下態由 `TLListRow` 給）；內建列不可點。**沒有 disabled** —— 內建列是「不可編輯」不是「暫時停用」，用「沒有 chevron」表達 |
| 選取 | selected / unselected / indeterminate | N/A —— 動作清單不做選取 |
| 資料 | empty / loading / error | N/A —— 沒有動作就不會有這一列 |
| 內容極值 | 最短 / 最長 / 溢出 | 動作名長時**先截斷名字**，尾欄保持完整（尾欄是唯一的彩色元素，右緣要對齊） |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 內建動作名會隨語言換 —— 所以測試靠 `identifier` 而不是文字 |

## 5 度量與行為

| | |
|---|---|
| 列高／內距 | 由 `TLListRow` 決定 |
| 尾欄最小寬度 | `size.rowTailColumn` |

**尾欄用 `minWidth` 不是 `width`**：兩字標籤（「槓鈴」「機械」）的欄寬是 80，
但「自體重量」比它寬 —— `minWidth` 讓長標往左長、右緣仍然對齊；
寫死 `width` 會把長標壓成兩行。

### 文字與溢出

動作名一行截斷。尾欄 `fixedSize()` 永不縮小、永不換行。

### 動態

無自己的轉場，按下態由 `TLListRow` 提供。

## 6 配色 ★

自己沒有顏色。尾欄的分類色由 `TLEquipmentTag` 決定。

## 7 用法與禁用法

**用它**：動作庫的動作清單。

**易混淆**：`TemplateRow`（範本列）—— 那個左側有數字圓章、副標是組成摘要；
這個沒有圓章、右側是分類標籤。

**不要用它**：
- 顯示範本／循環／長期 —— 那三個各有自己的 L3
- 自己判斷要顯示肌群還是器材 —— 那是分組狀態，屬於呼叫端

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 從 `ExerciseListView` 抽出成 L3 | 階段 2 的分層落地。**這是第一個真正的 L3** |
| 2026-08-31 | 尾欄寬度 `80` 改成 `size.rowTailColumn` | 元件內部的字面值也是字面值 |
| 2026-08-31 | **驗證結果：純由 L2 組成，沒有缺任何分子** | 架構賭注在這一個上成立 |
