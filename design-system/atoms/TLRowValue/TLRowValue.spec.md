# TLRowValue

## 1 身分

| | |
|---|---|
| 層級 | L1 原子 |
| 職責 | 列表列右側的數值（可帶單位） |
| 原型 id | `4c` `5b` `14c` |
| 獨立使用 | **否 —— 必須置於 `TLListRow` 的 trailing** |
| 容器責任 | 與 chevron 的間距由列負責 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Atoms/TLRowValue.swift` |
| Preview | `design-system/atoms/TLRowValue/TLRowValue.preview.html` |
| Preview CSS | `components.preview.css` §TLRowValue |

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `value` | `String` | | 是 | — | 數值本身。已格式化好的字串，元件不做格式化 |
| `unit` | `String?` | | 否 | `nil` | 單位。`nil` ＝ 不顯示 |

**Slots** — N/A
**事件** — N/A（點擊由整列承接）

## 3 變體 variants

無。有沒有單位是**有沒有傳 prop**，不是變體。

## 4 狀態 states ★

<!-- states: default -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **只有 default。** 按下態由整列表現 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | N/A —— 沒有值就不要放這個元件 |
| 內容極值 | 最短 / 最長 / 溢出 / **數字最大位數** | 最短是一位數；實務上最長是 `999.5` 這種四位含小數。**不截斷** |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 數字本身不變；單位可能是 `kg`／`下`／`次` 這種短詞，長度差異小 |

## 5 度量與行為

| | |
|---|---|
| 數字字級 | `type.rowNumber`（display 家族 ＝ Caprasimo） |
| 單位字級 | `type.rowTitle`（中文家族） |
| 兩者間距 | `space.valueUnitGap` |
| 對齊 | firstTextBaseline —— 數字與單位的基線對齊，不是置中 |

**基線對齊很重要**：數字用 Caprasimo、單位用中文字體，兩支字體的字身框高度不同，
置中會讓單位看起來浮起來。

### 文字與溢出

**溢出**：不截斷。空間不夠時是列的責任去壓縮標題。

**Dynamic Type**：應跟隨。目前固定，等 C7a。

### 動態

無轉場。

## 6 配色 ★

| 用途 | token |
|---|---|
| 數字 | `textPrimary` |
| 單位 | `textSecondary` |

單位比數字淡一階：數字是資訊，單位是脈絡。

## 7 用法與禁用法

**用它**：列右側要顯示一個數值時。

**易混淆**：`TLSettingsValue`（設定列右側的值）—— 那個是**文字**（用中文字體），
這個是**數字**（用 Caprasimo、可帶單位）。看到數字就用這個。

**不要用它**：
- 放純文字 —— Caprasimo 是為數字設計的，中文字會很奇怪
- 自己做格式化 —— 傳進來的應該是格式化好的字串，小數位數是呼叫端的決定
- 放兩個以上的數值 —— 一列一個答案

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `TLListRow.swift` 拆成獨立檔 | 那個檔有 4 個 public 元件 |
| 2026-08-30 | 字級 `display(16)` → `type.rowNumber`、間距 `4` → `space.valueUnitGap` | 元件內部的字面值也是字面值 |
| 2026-08-30 | 單位色 `neutral700` → `textBody` → **`textSecondary`** | `neutral700` 被用 16 處卻沒有語意角色，所以先命名為 `textBody`。設計端隨即指出**兩個 token 同值就是一個 token**，並把 `textSecondary` 本身移到 `neutral.700`（為了 4.5:1）。所以 `textBody` 併入 `textSecondary` 並刪除，值不變 |
