# TLPageHeader

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 頁面主標，回答「這是哪裡」 |
| 原型 id | 每一頁 |
| 獨立使用 | 是 |
| 容器責任 | 自己負責上邊距；**左右邊距由畫面給** |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLPageHeader.swift` |
| Preview | `design-system/molecules/TLPageHeader/TLPageHeader.preview.html` |
| Preview CSS | `components.preview.css` §TLPageHeader |

**組成**：不由其他 `TL*` 元件組成（純文字排版）。`accessory` 通常由呼叫端放 `TLCircleIconButton`。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `title` | `Text` | | 是 | — | 主標。允許兩行 |
| `kicker` | `Text?` | | 否 | `nil` | 主標上方的小標。`nil` ＝ 不顯示 |

**Slots** — `accessory`：主標右側的操作，預設空。通常放一顆 `TLCircleIconButton`。
**事件** — N/A（互動歸 accessory 自己）

## 3 變體 variants

無變體，但**有三種填法**（同一個 API）：

| 填法 | 說明 |
|---|---|
| 純標題 | 只傳 `title` |
| 標題 ＋ 右側圓鈕 | 傳 `accessory` |
| 標題 ＋ 上方 kicker | 傳 `kicker` |

## 4 狀態 states ★

<!-- states: default -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **只有 default。** 標題不可互動；accessory 的按下態由它自己處理 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | N/A —— 標題是必填 |
| 內容極值 | 最短 / 最長 / 溢出 | **主標允許兩行**（`lineLimit(2)`），超過就截斷。accessory 永遠不被壓縮 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 英文主標較長，兩行的情況比中文常見 —— 設計時要用最長的英文標題檢查 |

## 5 度量與行為

| | |
|---|---|
| 主標字級 | `type.pageTitle` ＋ `bold`，字距 `-0.02em` |
| kicker 字級 | `type.kicker` ＋ `semibold`，大寫，字距 `type.kickerTracking` |
| 上邊距 | `space.headerTop` |
| kicker 與主標之間 | `space.kickerGap` |
| 主標與 accessory 之間 | `space.gapM`，baseline 對齊 |
| 最小寬度 | 主標可壓到單字換行；accessory 不縮 |
| 壓縮行為 | **主標先讓**（換行→截斷），accessory 保持原尺寸 |

### 文字與溢出

**溢出**：主標兩行後截斷；`fixedSize(vertical:)` 確保第二行不被壓掉。

**多語系寬度**：英文主標普遍較長。有 accessory 時可用空間更少，
要用「最長英文標題 ＋ accessory」這個組合檢查。

**Dynamic Type**：應跟隨。目前固定，等 C7a。34pt 的主標是全 app 最大的文字，
放大後最容易爆版，屆時要優先驗它。

### 動態

無轉場。

## 6 配色 ★

| 用途 | token |
|---|---|
| 主標 | `textPrimary` |
| kicker | `actionPressed` |

**kicker 用 accent 而不是灰**：它在這裡的作用是「這一頁屬於哪個脈絡」，
是有意義的資訊而不是裝飾。這也是它跟 `TLSectionHeader` 的差異（那個預設是灰的）。

## 7 用法與禁用法

**用它**：每一頁的開頭。

**易混淆**：`TLBackBar`（返回列）—— 這個回答「這是哪裡」，那個回答「怎麼回去」。
兩者常上下相鄰，drill-in 子頁通常兩個都有。

**不要用它**：
- 一頁放兩個 —— 主標只有一個，第二層用 `TLSectionHeader`
- 把返回鈕塞進 accessory —— 返回是 `TLBackBar` 的事，位置也不同
- 用它當區塊標題 —— 字級差太多（34 vs 10.5）

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `Components/` 移到 `Molecules/` | 分層落地 |
| 2026-08-30 | 上邊距 `22`、kicker 間距 `8` 改成 token | 元件內部的字面值也是字面值 |
