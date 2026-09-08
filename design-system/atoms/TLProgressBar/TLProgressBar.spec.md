# TLProgressBar

## 1 身分

| | |
|---|---|
| 層級 | L1 原子 |
| 職責 | 水平進度條 |
| 原型 id | `13a` `13c` `5d` |
| 獨立使用 | 是 |
| 容器責任 | 寬度由容器決定（它撐滿）；上下間距由容器給 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Atoms/TLProgressBar.swift` |
| Preview | `design-system/atoms/TLProgressBar/TLProgressBar.preview.html` |
| Preview CSS | `components.preview.css` §TLProgressBar |

**組成**：N/A（L1 原子）

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `ratio` | `Double` | `0`–`1`（元件內部夾住） | 是 | — | 進度。超出範圍會被夾到邊界，不會畫爆 |
| `track` | `Color` | 只吃語意 token | 否 | `surfaceTrack` | 軌道色。見第 3 節 |

**Slots** — N/A
**事件** — N/A（唯讀）

## 3 變體 variants

無變體，但**軌道色是 prop**：

| 放在哪 | 軌道 |
|---|---|
| 群組容器或淺卡（`surfaceRaised` 底） | `surfaceTrack`（預設） |
| 深卡（`neutral-300` 底，長期課表詳情） | 呼叫端傳**更淺**的一階 |

**為什麼軌道色要開成 prop**：它會疊在深淺不同的底上，軌道要跟所在的底**有對比** ——
淺底上要更深、深底上要更淺。寫死的話在其中一種底上會整條消失。

## 4 狀態 states ★

<!-- states: empty, partial, full -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **不可互動**，唯讀顯示 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | `ratio` 0 是合法的（空進度）。沒有 loading／error —— 那要由呼叫端決定要不要顯示這個元件 |
| 內容極值 | 0 / 中間 / 1 / 超界 | 超出 0–1 會被夾住，這是刻意的：進度算錯時寧可畫滿也不要畫出容器 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | N/A —— 無文字 |

## 5 度量與行為

| | |
|---|---|
| 高度 | `size.progressBar` |
| 圓角 | capsule（兩端全圓） |
| 寬度 | 撐滿容器 |
| 最小寬度 | 無下限 —— 極窄時仍是一條線 |
| 壓縮行為 | 隨容器縮，不影響其他元素 |

### 文字與溢出

無文字。

### 動態

目前無轉場 —— 進度變動時直接跳。**已知缺口**：這個 app 的進度來自「完成了幾天」，
變動是離散且低頻的，所以先不做；真要做用 `motion.base`。

## 6 配色 ★

| 用途 | token |
|---|---|
| 已完成 | `actionPrimary` |
| 軌道 | 見第 3 節（prop） |

## 7 用法與禁用法

**用它**：表達「N 之於總數」的完成度。

**易混淆**：`TLSegmentedControl`（切換檢視）—— 那個可互動、表達選擇；
這個唯讀、表達比例。

**不要用它**：
- 表達不確定的等待 —— 它是決定性的比例，不是 spinner
- 當分隔線 —— 那是 `TLDivider`
- 自己算比例然後傳 0 或 1 —— 直接傳算式，夾住是元件的責任

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 從 `ProgramListView` 與 `ProgramDetailView` 抽出 | 兩處各手工重建一份（`GeometryReader` ＋ 兩個 `Capsule`），只差軌道色（一個更深、一個更淺，剛好是不能寫死的證據）。**設計文件的 L1 清單本來就有 `TLProgressBar`，只是實作沒有** |
| 2026-08-31 | 高度 `6` 改成 `size.progressBar` | 元件內部的字面值也是字面值 |
