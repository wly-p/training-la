# TLDividedVStack

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 垂直堆疊子項，並在**相鄰兩項之間**插入分隔線 |
| 原型 id | 所有群組的內部結構 |
| 獨立使用 | 是，但多數情況應該用包了它的 `TLGroup` |
| 容器責任 | 只管分隔線與堆疊；圓角與底色是 `TLGroup` 的事 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLDividedVStack.swift` |
| Preview | `design-system/molecules/TLDividedVStack/TLDividedVStack.preview.html` |

## 2 介面 ★

**Props** — 無。

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| （無） | | | | | |

**Slots** — `content`：要堆疊的子項。
**事件** — N/A

## 3 變體 variants

無。

## 4 狀態 states ★

<!-- states: default -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **只有 default。** 不可互動 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | empty 時渲染成高度 0，不畫任何線 |
| 內容極值 | 0 / 1 / 多項 | 0 與 1 項都不畫線；n 項畫 n−1 條 |
| 主題 | light / dark | 兩者都有（線色來自 `TLDivider`） |
| 語言 | 中文 / 英文 | 由各子項自己處理 |

## 5 度量

| | |
|---|---|
| 子項間距 | 0 —— 子項自己有高度，分隔線佔 `size.hairline` |
| 分隔線 | 由 `TLDivider` 決定 |

## 6 配色 ★

自己沒有顏色。

## 7 文字行為

自己無文字。

## 8 動態

無轉場。**已知限制**：子項動態增減時分隔線沒有動畫，會直接跳。

## 9 無障礙

- 不是 accessibility element，VoiceOver 逐子項走過。
- 分隔線不會被念到（`TLDivider` 沒有語意）。

## 10 用法與禁用法

**用它**：需要「頭尾不畫線」的堆疊，但**不需要**卡片的圓角與底色時。

**易混淆**：`TLGroup`（群組容器）—— 那個是這個 ＋ 圓角 ＋ 底色。
**多數情況要的是 `TLGroup`**；直接用這個是少數情形（例如已經有自己的容器）。

**不要用它**：
- 當一般的 `VStack` 用 —— 它會硬加分隔線
- 期待它有間距 —— 子項間距是 0，靠分隔線區隔

## 11 組成 ★

由 `TLDivider`（L1）組成。

## 12 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `Support/TLDividedVStack.swift` 拆出，移進 `Molecules/` | 一個檔兩個 public 元件；而且分隔線是原子、堆疊器是分子 |

**實作備註**：用 `_VariadicView` 解析子 View，才能對「一組異質靜態列」（如設定頁）
自動加分隔線，不必逼呼叫端改成 data-driven 的 `ForEach`。那是私有 API，
若未來失效，替代方案是要求呼叫端傳陣列 —— 代價是所有呼叫端都要改。
