# TLSettingsValue

## 1 身分

| | |
|---|---|
| 層級 | L1 原子 |
| 職責 | 設定列右側顯示「目前的值」 |
| 原型 id | `4b` |
| 獨立使用 | **否 —— 必須置於 `TLSettingsRow` 的 trailing** |
| 容器責任 | 與 chevron 的間距由列的 `trailingGap` 決定 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Atoms/TLSettingsValue.swift` |
| Preview | `design-system/atoms/TLSettingsValue/TLSettingsValue.preview.html` |
| Preview CSS | `components.preview.css` §TLSettingsValue |

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `text` | `Text` | | 是 | — | 值本身。吃 `Text` 不是 `String`，呼叫端用 `localText` 建好再傳 |

**Slots** — N/A
**事件** — N/A（不可互動；點擊由整列承接）

## 3 變體 variants

無。

## 4 狀態 states ★

<!-- states: default -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **只有 default。** 按下態由整列表現 |
| 選取 | selected / unselected / indeterminate | N/A —— 它顯示值，不表達選取 |
| 資料 | empty / loading / error | N/A —— 呼叫端保證有值；沒有值就不要放這個元件 |
| 內容極值 | 最短 / 最長 / 溢出 | 最短是一個字（「開」）；長值會擠壓標題，見第 7 節 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 英文值通常較長（「跟隨系統」vs「Follow System」），是主要的溢出來源 |

## 5 度量

| | |
|---|---|
| 字級 | `type.rowValue` |
| 顏色 | 見第 6 節 |
| 內距 | 無 —— 由列給 |
| 最小寬度 | 無下限，內容多短就多短 |
| 壓縮行為 | **標題先讓** —— 值是列的答案，截斷它等於讓這一列失去意義 |

## 6 配色 ★

| 用途 | token |
|---|---|
| 值文字 | `textSecondary` |

**為什麼是二級不是三級**：值比標題輕（它是答案不是問題），但比 chevron 重
（chevron 是裝飾，值要讀得到）。判準是**會不會被逐字讀** —— 值會，所以用二級。

## 7 文字行為

**溢出**：不主動截斷。空間不夠時是列的責任去壓縮標題。

**多語系寬度**：英文值普遍比中文長。設計時要用最長的英文值檢查，
而不是用中文值決定列的排版。

**Dynamic Type**：應跟隨（它是文字）。目前固定，等 C7a。

## 8 動態

值改變時無轉場 —— 設定列的值多半是換頁選完才回來，沒有原地變化的情境。

## 9 無障礙

- **自己不掛 label**。VoiceOver 應該把「標題＋值」當成一個單位念出來
  （例：「主題，深色」），所以那是列的 `accessibilityValue:` 的責任，不是這個元件的。
- 不掛 `accessibilityIdentifier`。

## 10 用法與禁用法

**用它**：設定列要顯示目前的值時。

**易混淆**：`TLRowValue`（列表列的右側數值）—— 那個是**數字**（用 Caprasimo、可帶單位），
這個是**文字**（用中文字體）。看到數字就用 `TLRowValue`。

**不要用它**：
- 放數字 —— 數字用 `TLRowValue`，字體不同
- 當第二行副標 —— 副標是列的 `subtitle`，位置與字級都不一樣
- 沒有值時放一個空的 —— 那會留下一塊看不見的空白，不如不放

## 11 組成 ★

N/A（L1 原子）。

## 12 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `TLSettingsRow.swift` 拆成獨立檔 | 那個檔有 3 個 public 元件，違反契約第 1 條 |
| 2026-08-30 | 字級從字面 `14` 改成 `type.rowValue` | 14 原本是 `TLFont.zh(14)` 的字面值。順帶發現字級尺度缺這一階：`rowSub 11.5` 與 `rowTitle 15` 之間沒有東西 |
| 2026-08-30 | 顏色從 `neutral600` 改成 `textSecondary` | 值相同，改用語意層才有深色的位置 |
