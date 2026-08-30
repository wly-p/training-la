# TLSectionHeader

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 區塊標題 —— 說明它下方那張卡是什麼 |
| 原型 id | 每一頁 |
| 獨立使用 | 是 |
| 容器責任 | 自己負責與下方群組的間距；左右邊距由畫面給 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLSectionHeader.swift` |
| Preview | `design-system/molecules/TLSectionHeader/TLSectionHeader.preview.html` |
| Preview CSS | `components.preview.css` §TLSectionHeader |

**組成**：不由其他 `TL*` 元件組成（文字 ＋ 按鈕樣式）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `title` | `Text` | | 是 | — | 區塊名。會自動轉大寫 |
| `tint` | `Color` | 只吃語意 token | 否 | `textTertiary` | 標題色。進行中的區塊用 `actionPressed` |
| `actionLabel` | `Text` | | 否 | — | 右側文字操作的文案。與 `action` 成對 |
| `action` | `() -> Void` | | 否 | — | 右側文字操作。與 `actionLabel` 成對 |

**Slots** — N/A（右側只收文字操作，不收任意內容 —— 見第 10 節）
**事件** — `action`

## 3 變體 variants

| 變體 | 說明 |
|---|---|
| 純標題 | 只傳 `title` |
| 標題 ＋ 文字操作 | 傳 `actionLabel` ＋ `action` |

`tint` 不算變體，它是同一個東西的著色。

## 4 狀態 states ★

<!-- states: default -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | 標題本身不可互動；文字操作的按下態由按鈕樣式處理 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | N/A —— 標題是必填 |
| 內容極值 | 最短 / 最長 / 溢出 | 標題與操作競爭同一行；標題長時操作會被推到最右仍保持完整 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 英文會被轉大寫，寬度增加明顯 —— 這是主要的溢出來源 |

## 5 度量與行為

| | |
|---|---|
| 字級 | `type.kicker` ＋ `semibold`，大寫，字距 `type.kickerTracking` |
| 下方間距 | `space.sectionHeaderGap` |
| 對齊 | firstTextBaseline —— 標題與操作的基線對齊 |

### 文字與溢出

**大寫是元件做的**（`textCase(.uppercase)`），呼叫端傳原文即可。
中文不受影響，英文會全大寫。

**多語系寬度**：英文大寫後明顯變寬。有右側操作時可用空間更少。

**Dynamic Type**：應跟隨。10.5pt 已經是全 app 最小的字，放大優先度高。

### 動態

無轉場。

## 6 配色 ★

| 用途 | token |
|---|---|
| 標題（預設） | `textTertiary` |
| 標題（進行中） | `actionPressed` |
| 文字操作 | 由 `tlText` 按鈕樣式決定 |

`textTertiary` 對容器底是 **4.0:1** —— 過得了大字與圖示的 3:1，過不了正文的 4.5:1。
區塊標題是「掃視就過的標示」而不是要讀完的句子，所以用它是對的。

## 7 用法與禁用法

**用它**：一張卡需要說明它是什麼時。

**易混淆**：`TLPageHeader` 的 `kicker`（主標上方的小標）—— 字級與樣式幾乎一樣，
但那個屬於**頁面**、預設是 accent 色；這個屬於**區塊**、預設是灰的。

**不要用它**：
- 右側放圖示按鈕 —— 這裡只收文字操作，圖示操作屬於 `TLPageHeader` 的 accessory
- 一個區塊只有一列時還加標題 —— 標題與列名容易重複（`handoff-20` A 節就砍掉過一個）
- 傳已經大寫的字串 —— 大寫是元件的視覺處理，來源該是原文

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `Components/` 移到 `Molecules/` | 分層落地 |
| 2026-08-30 | 下方間距 `10` 改成 `space.sectionHeaderGap` | 元件內部的字面值也是字面值 |
| 2026-08-30 | 預設色 `neutral500` → `textTertiary` | 值相同，改用語意層。⚠ 順帶量到它對容器底只有 2.6:1 |
