# ExerciseCompleteBand

## 1 身分

| | |
|---|---|
| 層級 | L3 有機體 |
| 職責 | 動作或課表做完時的完成區（16b／16e） |
| 原型 id | `16b` `16e` |
| 獨立使用 | 是（它取代輸入色帶的位置） |
| 容器責任 | 左緣要貼齊螢幕，所以它自己抵銷外層的頁面邊距 |
| 實作 | `Packages/Training/Sources/TrainingPresentation/Components/ExerciseCompleteBand.swift` |
| Preview | `design-system/organisms/ExerciseCompleteBand/ExerciseCompleteBand.preview.html` |
| Preview CSS | `components.preview.css` §ExerciseCompleteBand |

**組成**：不由 `TL*` 元件組成（自己的色帶形狀 ＋ `.tlPrimary` 按鈕樣式）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `isPlanFullyDone` | `Bool` | | 是 | — | 課表整份做完（16e）還是只有這個動作（16b）。決定文案、按鈕數、主鈕行為 |
| `title` | `Text` | | 是 | — | 標題 |
| `message` | `String` | | 是 | — | 說明句。**呼叫端算好**（16e 要帶整場統計） |
| `primaryTitle` | `String` | | 是 | — | 主鈕文案 |
| `oneMoreSetLabel` | `Text` | | 是 | — | 「加一組」 |
| `addExtraLabel` | `Text` | | 是 | — | 「加練」（只有 16e 用得到） |
| `onOneMoreSet` | `() -> Void` | | 是 | — | 同一個動作再來一組 |
| `onAddExtra` | `() -> Void` | | 是 | — | 開選擇器加新動作 |
| `onPrimary` | `() -> Void` | | 是 | — | 下一個動作／結束訓練 |

**Slots** — N/A
**事件** — 三個 closure

## 3 變體 variants

| `isPlanFullyDone` | 圖示 | 按鈕 |
|---|---|---|
| `false`（16b 動作做完） | `checkmark` | 加一組 ｜ 下一個 |
| `true`（16e 課表做完） | `flag` | 加一組 ｜ 加練 ｜ 結束訓練 |

**「加一組」在兩張卡的位置與尺寸完全相同** —— 最後一個動作同時是「再一組」與「加練」的
最後機會，兩個層級都要在。副按鈕用 `minWidth` 固定起跳寬度就是為了這件事。

## 4 狀態 states ★

<!-- states: exerciseDone, planDone -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | 三顆按鈕各自有按下態（由按鈕樣式給）。整條色帶不可點 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | N/A —— 沒做完就不會出現 |
| 內容極值 | 最短 / 最長 / 溢出 | 主鈕 `minimumScaleFactor(0.75)`：16e 三顆並排時只剩約 135pt，英文比中文長 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | **這是全 app 中英差異最敏感的元件** —— 三顆按鈕擠在一行 |

## 5 度量與行為

| | |
|---|---|
| 上下內距 | `space.rowInset` |
| 左內距 | `space.page`（再用負邊距抵銷外層，讓左緣貼齊螢幕） |
| 右側圓角 | `radius.band` 兩角 |
| 副按鈕最小寬 | `size.bandButtonMinW` |
| 按鈕間距 | `space.labelGap` |

**不對稱形狀**：左緣貼齊螢幕、右緣不到底。它跟輸入色帶是同一個形狀 ——
**同一位置、同一形狀，只換底色與內容**，所以誤按的人不會覺得畫面跳掉。

### 動態

無自己的轉場（出現與消失由呼叫端的狀態切換帶）。

## 6 配色 ★

| 用途 | token |
|---|---|
| 底 | `sage-200` |
| 標題／圖示 | `sage-900` |
| 說明 | `sage-800` @ 85% |
| 副按鈕框 | `sage-400` |

**綠色是全 app 唯一「值得高興」的訊號**（另一處是完成摘要的 PR 條）。

## 7 用法與禁用法

**用它**：動作或課表做完的那一刻。

**易混淆**：完成摘要 sheet（13a）—— 那是整場結束後的頁；這是就地的一條帶。

**不要用它**：
- 做成彈窗 —— **舊實作就是彈窗**：它出現在狀態已經前進之後，不是防誤按而是事後追問，
  還跟組表上既有的 ↩ 重疊
- 蓋住組表 —— 誤按的人要看得到 ↩ 才能復原

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-09-04 | 從 `ActiveWorkoutView` 抽出成 L3 | 那個檔自己組了 26 個 view，這一組佔 3 個 |
| 2026-09-04 | 色帶圓角 `40` 改吃 `radius.band`、副按鈕 `80` 改吃 `size.bandButtonMinW` | 這兩個值**躲過了前四版的 ratchet**：`UnevenRoundedRectangle` 的角不叫 `cornerRadius`、`minWidth` 的 W 是大寫 |
