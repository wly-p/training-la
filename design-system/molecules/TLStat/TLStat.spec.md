# TLStat

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 一個統計數字 ＋ 它的標籤 |
| 原型 id | `6b` `13a` |
| 獨立使用 | 是（通常並排放在卡裡） |
| 容器責任 | 並排時的間距由容器給（`space.statGap`） |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLStat.swift` |
| Preview | `design-system/molecules/TLStat/TLStat.preview.html` |
| Preview CSS | `components.preview.css` §TLStat |

**組成**：不由其他 `TL*` 元件組成。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `value` | `Text` | | 是 | — | 數字。**呼叫端負責格式化** —— 元件不做計算 |
| `label` | `Text` | | 是 | — | 標籤 |
| `numberFont` | `Font` | | 否 | `type.cardNumber` | 數字字級。見第 3 節 |
| `alignment` | `HorizontalAlignment` | `leading` / `center` / `trailing` | 否 | `leading` | 三個並排時中間那個置中、最右那個靠右 |

**Slots** — N/A
**事件** — N/A（唯讀）

## 3 變體 variants

無變體，但數字字級是 prop：

| 用在哪 | 字級 |
|---|---|
| 訓練首頁的週統計 | `type.cardNumber`(26，預設) |
| 完成摘要的統計 | 34 |

⚠ **34 目前沒有角色名** —— display 家族的尺度還沒收斂（第二批），
所以那一階由呼叫端傳。收斂之後這個 prop 應該換成 enum。

## 4 狀態 states ★

<!-- states: leading, trailing -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **一個都沒有**，它唯讀 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | N/A —— 沒有數字就不要放這個元件 |
| 內容極值 | 最短 / 最長 / 溢出 | 數字不換行；標籤可換行 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 標籤在英文較長，是並排時的寬度決定因素 |

## 5 度量與行為

| | |
|---|---|
| 數字與標籤之間 | `space.titleSubGap` |
| 數字字級 | 見第 3 節（display 家族） |
| 標籤字級 | `type.rowSub` |

**標籤在下面不是上面**：掃視時先看到數字，標籤只在需要確認「這是什麼」時才讀。

### 動態

無。

## 6 配色 ★

| 用途 | token |
|---|---|
| 數字 | `textPrimary` |
| 標籤 | `neutral-600` |

## 7 用法與禁用法

**用它**：卡片裡並排的統計數字。

**易混淆**：`TLRowValue` —— 那個是**列右側的值**（跟列名同一行）；
這個是**上下兩行**、獨立成塊。

**不要用它**：
- 讓它自己算數字 —— 元件不做計算（正典 §4 規則二之二），格式化在呼叫端
- 只放數字不放標籤 —— 沒有標籤的數字讀不出是什麼

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-09-04 | 新增 | `TrainingHomeView` 與 `FinishWorkoutSheet` **各有一份一模一樣的 `statNumber`**，只差數字字級與對齊。跨檔的重複比同檔的更難發現，因為讀任何一邊都看不出來 |
