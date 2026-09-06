# TLTitleWithTag

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 名稱 ＋ 緊跟在後的小標籤 |
| 原型 id | `12c` `14c` |
| 獨立使用 | 是（它是一段標頭排法，不需要容器） |
| 容器責任 | 字體與顏色**由呼叫端先套在 `title` 上**（大標與列各有各的） |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLTitleWithTag.swift` |
| Preview | `design-system/molecules/TLTitleWithTag/TLTitleWithTag.preview.html` |
| Preview CSS | `components.preview.css` §TLTitleWithTag |

**組成**：由 `TLEquipmentTag`（L2）組成。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `title` | `Text` | | 是 | — | 已經套好字體與顏色的名稱 |
| `equipment` | `String` | | 是 | — | 跟在名稱後的標籤文字 |
| `name` | `String` | | 是 | — | 便利建構子用：純字串名稱（使用者資料，不本地化） |
| `font` | `Font` | | 否 | `type.rowTitle` semibold | 便利建構子用：套在名稱上的字體 |

**兩個建構子**：`(title:equipment:)` 給已經有樣式的 `Text`；
`(name:equipment:font:)` 給純字串，自己套字體與 `textPrimary`。

**Slots** — N/A
**事件** — N/A

## 3 變體 variants

無。差別只在呼叫端套的字體（大標 vs 列）。

## 4 狀態 states ★

<!-- states: default -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **不可互動**，純標示 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | N/A —— 沒有標籤就不要用這個排法，直接放名稱 |
| 內容極值 | 最短 / 最長 / 溢出 | **名稱先截斷，標籤永不被壓縮**（`layoutPriority`）。這是這個元件存在的理由之一 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 英文標籤明顯較長，是這一行寬度的決定因素 |

## 5 度量與行為

| | |
|---|---|
| 名稱與標籤之間 | `space.gapS` |
| 名稱字級 | 呼叫端決定（列是 `type.rowTitle`、大標是頁面自己的） |

### 文字與溢出

兩個容易做錯的細節，也就是**為什麼它是元件而不是散在各畫面的兩行程式碼**：

1. 名稱 `lineLimit(1)` ＋ tail truncate —— 少了它，長名稱把標籤推到第二行
2. 標籤 `layoutPriority(1)` —— 少了它，長名稱把標籤壓成一團

### 動態

無。

## 6 配色 ★

自己沒有顏色。名稱的顏色由呼叫端套，標籤的顏色由 `TLEquipmentTag` 決定。

## 7 用法與禁用法

**用它**：**單一項目**的標頭 —— 進行中的畫面、預覽 sheet、詳情頁、能力值四處。

**易混淆**：`TLEquipmentTag` 單用 —— 那是列尾欄的標籤；這個是名稱後面緊跟一顆。

**不要用它**：
- **清單列不要用**。標籤跟著名稱浮動時，每一列的左緣都不同，整份清單會出現鋸齒。
  清單的標籤在尾欄（`18b`）或細節行（`19a`）
- 放兩顆標籤 —— 沒有這個排法

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 從 `TLEquipmentTag.swift` 拆成獨立檔、改名 | 原名 `TLExerciseNameWithEquipment` —— **名字帶 domain 詞彙**，L2 不該認識 domain（正典 §4 規則三）。順帶解掉一檔兩元件 |
| 2026-08-31 | 名稱與標籤的間距 `8` 改成 `space.gapS` | 元件內部的字面值也是字面值 |
