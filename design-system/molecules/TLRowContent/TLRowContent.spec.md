# TLRowContent

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 列的**內容排版**：左件 ＋ 主副標 ＋ 右件 ＋ 指向記號 |
| 原型 id | `4c` `5b` `8a` |
| 獨立使用 | **否 —— 它沒有外框，必須由 `TLListRow` 或卡片式版面給** |
| 容器責任 | 左右內距、最小高度、可不可點，**全部由容器負責** |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLRowContent.swift` |
| Preview | `design-system/molecules/TLRowContent/TLRowContent.preview.html` |
| Preview CSS | `components.preview.css` §TLRowContent |

**組成**：由 `TLChevron`（L1）與 `TLTitleWithTag`（L2）組成；
slot 常放 `TLBadge`／`TLCheckCircle`／`TLRowValue`（皆 L1）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `title` | `Text` | | 是 | — | 列名 |
| `subtitle` | `Text?` | | 否 | `nil` | 第二行。內容規則是「組成摘要」，見第 7 節 |
| `equipment` | `String?` | | 否 | `nil` | 標題右側的小標。給的話走 `TLTitleWithTag` 排法 |
| `showChevron` | `Bool` | | 否 | `false` | 是否通往下一層 |

**Slots** — `leading`（左側，通常放 `TLBadge` 或 `TLCheckCircle`）、
`detail`（標題下方的細節行，放得下非文字元素）、
`trailing`（右側，通常放 `TLRowValue`）。
**事件** — 無。**它不可點** —— 點擊是外框的事。

**另外對外給一個值**：`preferredMinHeight` —— 這一列「應該」多高。
它不是 prop 而是**輸出**：容器要不要用它自己決定（`TLListRow` 用，卡片式版面通常不用）。

## 3 變體 variants

無變體，但有三種填法（同 `TLListRow`）：

| 填法 | 組成 |
|---|---|
| 圖示型 | `leading` 放 `TLBadge` ＋ 主副標 ＋ `trailing` 放 `TLRowValue` ＋ chevron |
| 純文字型 | 主標 ＋ `trailing` |
| 可勾選型 | `leading` 放 `TLCheckCircle` ＋ 主副標，**沒有 chevron** |

## 4 狀態 states ★

<!-- states: single, withSub, withDetail -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **一個都沒有。** 它不可點 —— 按下態是 `TLListRow` 的事。這是刻意的：把互動留在這裡，卡片式版面就得繼承一個它用不到的按鈕 |
| 選取 | selected / unselected / indeterminate | 由 `leading` 放的 `TLCheckCircle` 表達 |
| 資料 | empty / loading / error | N/A —— 沒有資料就不會有這一列 |
| 內容極值 | 最短 / 最長 / 溢出 | 主標與副標各自一行截斷；`leading`／`trailing` 不縮 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 副標是全 app 中英落差最大的文字 |

三個 state 是**填法**不是互動態：`single`（只有主標）、`withSub`（主副標）、
`withDetail`（主標 ＋ 細節行）。它們決定 `preferredMinHeight`。

## 5 度量與行為

| | |
|---|---|
| 左件與文字之間 | `space.gapM` |
| 主標與副標之間 | `space.titleSubGap` |
| 文字與右件之間 | 最小 `space.gapS`（中間是彈性空白） |
| 主標字級 | `type.rowTitle` |
| 副標字級 | `type.rowSub` |
| `preferredMinHeight` | 有細節行 `size.rowWithDetail`；有副標 `size.rowWithSub`；否則 `size.row` |

**沒有左右內距、沒有高度、沒有底色** —— 這三件事不在這裡是這個元件存在的理由。

### 文字與溢出

主標一行截斷加 `…`；有 `equipment` 時改走 `TLTitleWithTag`（名稱截斷、標籤不縮）。
副標一行截斷。細節行與主標**共用同一條左緣** —— 器材不再需要自己的欄，對齊問題自然消失。

### 動態

無。轉場屬於外框。

## 6 配色 ★

| 用途 | token |
|---|---|
| 主標 | `textPrimary` |
| 副標 | `neutral-500` |

⚠ **副標目前是原始色階不是語意 token。** 文字階合併（`textSecondary` → neutral-700）
之後 Swift 端還沒遷移，全 app 有九十幾處還直接用 `neutral-500`。
CSS 鏡像跟著**實作**走而不是跟著意圖走 —— 否則設計端看到的顏色與 app 不同，
而那正是這整輪重構要消滅的東西。遷移列在 `CHANGELOG.md` 的已知缺口。

## 7 用法與禁用法

**用它**：需要「列的排版」但外框自己給的地方 —— 卡片式版面、右側要獨立可點的列。

**易混淆**：`TLListRow` —— 那個是**這個元件 ＋ 外框**（內距、最小高度、整列可點）。
判準：整列點下去是一個動作嗎？是就用 `TLListRow`。

**不要用它**：
- 直接放進 `TLGroup` —— 沒有內距會貼邊，那是 `TLListRow` 的工作
- 同時給 `subtitle` 與 `detail` —— 兩行第二內容沒有設計
- 把狀態放進副標 —— 狀態一律放右側，副標是組成摘要

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 從 `TLListRow` 拆出 | **階段 2 最重要的一個修正。** 長期課表的「進行中」卡手工重建了整個列（圓章＋主副標＋chevron），查下去不是偷懶而是**用不了**：`TLListRow` 把內容排版與列的外框綁在同一個型別，那張卡有自己的 padding、只有上半可點，外框全部不適用。拆開之後兩個呼叫端的手工重建都消失了 |
| 2026-08-31 | **記錄副標配色的鏡像落差** | Swift 用 `neutral-500`、語意層意圖是 `textSecondary`(neutral-700)。這是文字階合併後未遷移的殘留，不是這一輪能順手改的（會動到視覺） |
