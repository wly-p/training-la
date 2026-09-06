# TLEquipmentTag

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 列尾欄的分類標籤（器材或肌群） |
| 原型 id | `18b` `19a` |
| 獨立使用 | **否 —— 放在列的 trailing** |
| 容器責任 | 與相鄰元素的間距、尾欄寬度由列負責 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Components/TLEquipmentTag.swift` |
| Preview | `design-system/molecules/TLEquipmentTag/TLEquipmentTag.preview.html` |
| Preview CSS | `components.preview.css` §TLEquipmentTag |

**組成**：不由其他 `TL*` 元件組成（文字 ＋ capsule 底）

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `label` | `String` | | 是 | — | 標籤文字 |
| `identifier` | `String` | `equipmentTag` / `muscleTag` | 否 | `equipmentTag` | 測試定位鍵。**尾欄放什麼由呼叫端決定**，測試要分得出這一列標的是哪一種 |

**Slots** — N/A
**事件** — N/A（唯讀標示）

## 3 變體 variants

無。**它只有一種樣子** —— 分類色是固定的（鼠尾草綠）。

⚠ 見第 8 節：專案裡還有四種幾何不同的膠囊，那是待收斂的狀態。

## 4 狀態 states ★

<!-- states: default -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **不可互動**，純標示 |
| 選取 | selected / unselected / indeterminate | N/A —— 那是 `TLMuscleTag` 的事（可選的 chip） |
| 資料 | empty / loading / error | N/A —— 沒有分類就不要放這個元件 |
| 內容極值 | 最短 / 最長 / 溢出 | **永不縮小、永不換行**（`fixedSize`）。空間不足時該被截斷的是動作名 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 英文器材名（`Barbell`／`Bodyweight`）比中文長，是尾欄寬度的決定因素 |

## 5 度量與行為

| | |
|---|---|
| 字級 | `type.kicker` ＋ `semibold` |
| 內距 | 上下 `space.tagPadV`、左右 `space.tagPadH` |
| 圓角 | `radius.pill` |

### 文字與溢出

`fixedSize()` —— 永不縮小、永不換行。這是刻意的：
**空間不足時該被 truncate 的是動作名，不是分類標籤**（標籤短、資訊密度高）。

### 動態

無轉場。

## 6 配色 ★

| 用途 | token |
|---|---|
| 文字 | `sage-900` |
| 底 | `sage-200` |

**分類色是鼠尾草綠不是赭紅** —— 赭紅保留給「可操作的東西」，這是標示不是動作。

## 7 用法與禁用法

**用它**：列的尾欄要標一個分類時。

**易混淆**：`TLMuscleTag` —— 那個**可選取**（chip，有選中／未選狀態、可點）；
這個是**唯讀標示**。判準：點得下去嗎？點得下去用 `TLMuscleTag`。

**不要用它**：
- 表達狀態（進行中／已完成）—— 那是狀態膠囊，用色與語意都不同
- 放長句 —— 它 `fixedSize`，長句會把整列撐爛
- 一列放兩個 —— 尾欄只有一欄

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 補上規格 | 抽 `ExerciseRow` 時檢查 11 要求它的組成元件要有規格 |
| 2026-08-31 | 字級 `10.5` 與內距 `5`／`9` 改成 token | 元件內部的字面值也是字面值 |
| 2026-08-31 | **記錄膠囊幾何未收斂** | 專案裡有 5 種膠囊形狀的東西，幾何全不一樣：這個 `5/9`、`TLMuscleTag` `5/12`、進度膠囊 `5/10`、詳情頁膠囊 `7/14`、表單按鈕 `10/滿寬`。設計文件說 `TLTag` 是「capsule 5×12、11.5pt semibold、6 種 style」—— **也就是設計意圖是一個標籤六種顏色，實作卻在幾何上各自漂了**。統一是設計決策，已列進待問清單 |
