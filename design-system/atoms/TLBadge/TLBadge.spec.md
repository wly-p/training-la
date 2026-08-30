# TLBadge

## 1 身分

| | |
|---|---|
| 層級 | L1 原子 |
| 職責 | 列左側的圓章 —— 用一個字或數字代表這一項 |
| 原型 id | `4c` `5b` `9c` |
| 獨立使用 | **否 —— 必須置於 `TLListRow` 的 leading** |
| 容器責任 | 位置與間距由列負責 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Atoms/TLBadge.swift` |
| Preview | `design-system/atoms/TLBadge/TLBadge.preview.html` |
| Preview CSS | `components.preview.css` §TLBadge |

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `fill` | `Color` | 只吃語意 token | 否 | `categoryTag` 的淺階 | 圓章底色 |
| `size` | `CGFloat` | 只吃 `size.*` token | 否 | `size.badge` | 直徑 |
| `muscle` | `String` | | — | — | 便利建構子：填一個分類字 |
| `count` | `Int` | | — | — | 便利建構子：填一個數字 |
| `systemName` | `String` | | — | — | 便利建構子：填一個 SF Symbol |
| `tint` | `Color` | 只吃語意 token | 否 | 分類色的深階 | 圖示建構子的前景色 |

前四個是**互斥的便利建構子**，各自對應第 3 節的一種填法。`fill`／`size`／`tint` 是共用的調整項。

**Slots** — `content`：圓章裡的內容。三種便利建構子分別填字、數字、圖示。
**事件** — N/A（點擊由整列承接）

## 3 變體 variants

三個便利建構子，不是變體 —— 它們填的是同一個 slot：

| 建構子 | 內容 |
|---|---|
| `init(muscle:)` | 一個分類字（`type.badgeText`） |
| `init(count:)` | 一個數字（`type.rowNumber`，display 家族） |
| `init(fill:content:)` | 任意內容（圖示） |

## 4 狀態 states ★

<!-- states: default -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **只有 default。** 按下態由整列表現 |
| 選取 | selected / unselected / indeterminate | N/A —— 選取用 `TLCheckCircle`，兩者不會同時出現在 leading |
| 資料 | empty / loading / error | N/A —— 沒有內容就不要放這個元件 |
| 內容極值 | 1 字 / 2 字 / 數字位數 | **1–2 個字**。3 字以上會溢出圓形，那時該重新想這個分類的縮寫 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 中文一字即可；英文縮寫通常 2–3 字母，**這是最容易溢出的組合** |

## 5 度量與行為

| | |
|---|---|
| 直徑 | `size.badge` |
| 圓角 | `radius.pill`（正圓） |
| 文字字級 | `type.badgeText`（分類字）／ `type.rowNumber`（數字） |

### 文字與溢出

**溢出**：不截斷，會撐出圓形。這是設計上的訊號 ——
如果縮寫塞不下，該改的是縮寫不是元件。

**多語系寬度**：英文縮寫比中文長。設計分類縮寫時要同時想中英兩版。

**Dynamic Type**：不跟隨。圓章是固定尺寸的視覺標記，跟著字級長大會讓列高失控。

### 動態

無轉場。

## 6 配色 ★

| 用途 | token |
|---|---|
| 底（預設） | `categoryTag` 的淺階 |
| 文字 | `categoryTag` 的深階 |

**分類色是鼠尾草綠不是赭紅** —— 赭紅保留給「可操作的東西」。
圓章是標示不是動作，所以用分類色。

## 7 用法與禁用法

**用它**：清單列需要一個視覺錨點來快速分辨類別或數量時。

**易混淆**：`TLIconThumbnail`（列裡的方形圖片）—— 圓章是**字或數字**（抽象標示），
縮圖是**圖片**（具體預覽）。形狀也不同：圓 vs 方。

**不要用它**：
- 放 3 個字以上 —— 會撐出圓形
- 當可點的按鈕 —— 它是標示，點擊屬於整列
- 用赭紅底 —— 那個顏色保留給可操作的東西

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從四合一的 `TLListRow.swift` 拆成獨立檔 | 那個檔有 4 個 public 元件 |
| 2026-08-30 | 內部字級 `12`／`16`／`15` 改成 `type.badgeText`／`type.rowNumber`／`type.rowTitle` | 元件內部的字面值也是字面值 |
