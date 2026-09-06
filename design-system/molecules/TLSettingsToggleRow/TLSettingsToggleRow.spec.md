# TLSettingsToggleRow

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 設定頁裡的開關列 |
| 原型 id | `4b` `12a` |
| 獨立使用 | **否 —— 必須置於 `TLGroup` 之內** |
| 容器責任 | 圓角、底色、分隔線由 `TLGroup` 負責 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLSettingsToggleRow.swift` |
| Preview | `design-system/molecules/TLSettingsToggleRow/TLSettingsToggleRow.preview.html` |
| Preview CSS | `components.preview.css` §TLSettingsToggleRow |

**組成**：由 `TLToggle`（L1）組成。
`TLToggle` 的實作形式是 `ToggleStyle` 而不是 View，所以這裡是
`Toggle(...).toggleStyle(.tlSwitch)` 而不是實例化一個子 View。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `title` | `Text` | | 是 | — | 列名 |
| `hint` | `Text?` | | 否 | `nil` | 標題後方同一行的小灰字。**短詞用**（如「含震動」） |
| `subtitle` | `Text?` | | 否 | `nil` | 標題下方第二行。**整句用**。列高改吃 `size.rowWithSub` |
| `isOn` | `Binding<Bool>` | | 是 | — | 開關狀態 |

**Slots** — N/A（右側固定是開關）
**事件** — 透過 `isOn` binding 回寫

## 3 變體 variants

無變體，但**說明文字有兩種放法**（擇一，不要同時用）：

| 放法 | 用在 |
|---|---|
| `hint` | 短詞，跟標題同一行（「含震動」） |
| `subtitle` | 整句，第二行（「App 不在前景時以系統通知提醒」） |

**說明文字固定屬於某一列**，不要放在群組下方 ——
那會產生「這段在解釋整組還是最後一列」的歧義。

## 4 狀態 states ★

<!-- states: on, off, withHint, withSubtitle -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | 開關自己有按下態。**沒有 disabled** —— ⚠ 這是實際的缺口：通知開關在系統權限被拒時應該要能表達「打不開」，目前做不到（見第 12 節） |
| 選取 | selected / unselected / indeterminate | 開／關就是它的兩個狀態；沒有 indeterminate |
| 資料 | empty / loading / error | N/A |
| 內容極值 | 最短 / 最長 / 溢出 | 標題可換行；開關永遠不被壓縮 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | `subtitle` 是整句，英文明顯較長，第二行可能變兩行 |

## 5 度量與行為

| | |
|---|---|
| 列高 | 無 subtitle：`size.row`；有 subtitle：`size.rowWithSub` |
| 左右內距 | `space.rowInset` |
| 標題與 subtitle 之間 | `space.titleSubGap` |
| 標題與 hint 之間 | `space.titleHintGap` |
| 開關 | `size.switchW` × `size.switchH` |

### 文字與溢出

**溢出**：標題與 subtitle 都可換行，列高跟著長（`minHeight`）。

**多語系寬度**：`subtitle` 是整句，是全設定頁最長的文字。英文常會變成兩行。

**Dynamic Type**：應跟隨。這一列的文字最多，放大後高度增加最明顯。

### 動態

開關的滑動與底色轉換由 `TLSwitchToggleStyle` 提供。

## 6 配色 ★

| 用途 | token |
|---|---|
| 標題 | `textPrimary` |
| hint / subtitle | `textTertiary` |
| 開關（開） | `actionPrimary` |
| 開關（關） | `surfaceInput` |

**不可以用系統 `Toggle` 的預設樣式** —— 系統綠會讓整頁瞬間變回原生。

## 7 用法與禁用法

**用它**：設定頁裡的布林開關。

**易混淆**：`TLSettingsRow` ＋ trailing 放開關 —— **不要那樣做**。
底層不是 `Toggle` 的話會失去 `switches` 的測試可定位性。

**不要用它**：
- 開關以外的東西 —— 右側固定是開關，不是 slot
- `hint` 與 `subtitle` 同時用 —— 擇一，兩個都放會讓列變得很吵
- 把說明文字放到群組下方 —— 見第 3 節

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從三合一的 `TLSettingsRow.swift` 拆出 | 那個檔有 3 個 public 元件 |
| 2026-08-30 | 內部字面值 `3`／`6` 改成 token | 元件內部的字面值也是字面值 |
| 2026-08-30 | **記錄 disabled 缺口** | 體檢 P1-3 指出：通知授權被拒後，設定裡的開關**仍然顯示開著**，是一個會說謊的設定。要修那個，這個元件需要 disabled 態（或一個「被系統擋住」的表達）。已有 UI 設計票在排（通知授權時機與權限狀態顯示） |
