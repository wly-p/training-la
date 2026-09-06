# TLDivider

## 1 身分

| | |
|---|---|
| 層級 | L1 原子 |
| 職責 | 群組容器裡的列間分隔線 |
| 原型 id | 所有群組（`4b` `4c` `5b` …） |
| 獨立使用 | **否 —— 由 `TLDividedVStack` 自動插入，畫面層不該手動放** |
| 容器責任 | 左內縮由這個元件自己負責；頭尾不畫線是 `TLDividedVStack` 的責任 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Atoms/TLDivider.swift` |
| Preview | `design-system/atoms/TLDivider/TLDivider.preview.html` |
| Preview CSS | `components.preview.css` §TLDivider |

## 2 介面 ★

**Props** — 無。

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| （無） | | | | | |

**Slots** — N/A
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
| 資料 | empty / loading / error | N/A |
| 內容極值 | 最短 / 最長 / 溢出 | N/A —— 寬度由容器決定 |
| 主題 | light / dark | 兩者都有。半透明墨色，所以在任何底色上都成立 |
| 語言 | 中文 / 英文 | N/A |

## 5 度量與行為

| | |
|---|---|
| 高度 | `size.hairline` |
| 左內縮 | `space.rowInset` —— 對齊列內文字的起點 |
| 右側 | 不內縮，畫到容器邊緣 |

**為什麼左內縮右不縮**：分隔線的作用是「分開兩列的內容」，所以它從內容開始的地方起算。
兩邊都內縮會看起來像一條浮在中間的線；兩邊都不縮則會把群組切成上下兩塊。

### 文字與溢出

無文字。**Dynamic Type**：不跟隨。它是結構線，跟著字級變粗沒有意義。

### 動態

無。

## 6 配色 ★

| 用途 | token |
|---|---|
| 線 | `borderSubtle`（＝ `textPrimary` 的 8%） |

**用半透明而不是固定灰**：它會疊在不同的容器底上（`surfaceRaised`／`surfaceBase`），
半透明才能在每一種底上都保持同樣的對比關係。

## 7 用法與禁用法

**用它**：不要直接用。把列放進 `TLDividedVStack`（或用 `TLGroup`），分隔線會自動出現在正確的位置。

**易混淆**：容器外框 —— 那是 `TLGroup` 的圓角邊界，這個是**容器內部**的列間線。

**不要用它**：
- 手動放在畫面層 —— 那會繞過「頭尾不畫線」的規則，而那正是這套視覺的辨識點
- 當區塊分隔 —— 區塊之間用的是間距（`space.section`），不是線

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `Support/TLDividedVStack.swift` 拆出，移進 `Atoms/` | 一個檔兩個 public 元件；而且分隔線本身是原子、堆疊器是分子，層級不同 |
| 2026-08-30 | 高度從字面 `1` 改成 `size.hairline` | 新增這個 token 時一併收斂 |
