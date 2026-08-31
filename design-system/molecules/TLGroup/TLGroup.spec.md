# TLGroup

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 群組容器 —— 把一組列包成一張卡 |
| 原型 id | 每一頁 |
| 獨立使用 | 是 |
| 容器責任 | 自己負責圓角、底色、列間分隔線；**左右邊距由畫面給**（`space.page`） |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLGroup.swift` |
| Preview | `design-system/molecules/TLGroup/TLGroup.preview.html` |
| Preview CSS | `components.preview.css` §TLGroup |

**組成**：由 `TLDividedVStack`（L2）組成，後者再用 `TLDivider`（L1）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `border` | `Color?` | | 否 | `nil` | 描邊色。用來標「這一區是進行中的」。`nil` ＝ 無描邊 |

**Slots** — `content`：一組列。**異質靜態列也可以**（不必是 `ForEach`）——
分隔線靠 `_VariadicView` 解析子 View 自動插入。
**事件** — N/A（互動歸各列）

## 3 變體 variants

無。**這是刻意的** —— 一種容器樣式是這套視覺的辨識點，開變體會讓它散掉。

`border` 不算變體：它是「這一區進行中」的**標記**，不是另一種容器樣式。

## 4 狀態 states ★

<!-- states: default, bordered -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **只有 default。** 容器不可互動，互動歸各列 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | **empty 要注意**：沒有子項時會渲染成一個高度為 0 的圓角矩形（看不見但佔位）。呼叫端應該在沒有內容時不要放這個容器，或改用 `TLEmptyState` |
| 內容極值 | 1 列 / 多列 | 1 列時不畫任何分隔線；列數無上限 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 由各列自己處理 |

## 5 度量與行為

| | |
|---|---|
| 圓角 | `radius.container` |
| 底色 | 見第 6 節 |
| 內距 | 無 —— 列自己有 `space.rowInset` |
| 分隔線 | 由 `TLDividedVStack` 插入，頭尾不畫 |

### 文字與溢出

自己無文字。

### 動態

無轉場。列的按下態由列自己處理，**不會被容器的圓角裁掉** ——
按下態畫在列上，而列在容器的 clip 範圍內。

## 6 配色 ★

| 用途 | token |
|---|---|
| 容器底 | `surfaceRaised` |

**它比頁面底(`surfaceBase`)亮**：卡片是浮起來的，不是凹進去的。

## 7 用法與禁用法

**用它**：一組相關的列要成為視覺上的一張卡時。

**易混淆**：`TLSectionHeader`（區塊標題）—— 那個是卡**上方**的標籤，這個是卡本身。
兩者常一起出現但可以分開用：一張卡不一定要有標題。

**不要用它**：
- 包單一個非列的東西（例如一張圖）—— 那不是「一組列」，會拿到不該有的分隔線邏輯
- 巢狀 —— 卡中卡沒有設計，而且分隔線會亂
- 沒有內容時還放著 —— 見第 4 節的 empty

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `Support/` 移到 `Molecules/` | 它是元件不是支援工具；分層原本只存在於文件裡 |
| 2026-08-30 | 底色 `neutral100` → `surfaceRaised`、圓角維持 `radius.container` | 改用語意層才有深色的位置 |
| 2026-08-31 | 新增 `border` | 循環清單要標「進行中」的區塊，但這個元件不收描邊，於是呼叫端自己在外面疊了一個 `strokeBorder` 的 overlay —— 同一件事的第二份實作。跟 `TLSectionHeader` 的右側、`TLBadge(count:)` 的顏色同一型 |
