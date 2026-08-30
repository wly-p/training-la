# TLCheckCircle

## 1 身分

| | |
|---|---|
| 層級 | L1 原子 |
| 職責 | 可勾選的列右側，表達「這一項被選了」 |
| 原型 id | `12c` `12d`；也用在設定的選擇子頁 |
| 獨立使用 | **否 —— 必須置於列之內（`TLListRow`）** |
| 容器責任 | 位置與間距由列負責 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Atoms/TLCheckCircle.swift` |
| Preview | `design-system/atoms/TLCheckCircle/TLCheckCircle.preview.html` |

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `isChecked` | `Bool` | | 是 | — | 選中與否 |

**Slots** — N/A
**事件** — N/A（點擊由整列承接 —— 觸控目標是列，不是這個 22pt 的圓）

## 3 變體 variants

無。選中與否是**狀態**不是變體 —— 同一個元件的兩個樣子，由 `isChecked` 決定。

## 4 狀態 states ★

<!-- states: unselected, selected -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | 按下態由整列表現，這個元件不變 |
| 選取 | selected / unselected / indeterminate | **selected 與 unselected 是它的全部意義。** 沒有 indeterminate —— 目前沒有「部分選取」的情境；真要做要先補設計 |
| 資料 | empty / loading / error | N/A |
| 內容極值 | 最短 / 最長 / 溢出 | N/A —— 固定尺寸 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | N/A —— 無文字 |

## 5 度量

| | |
|---|---|
| 直徑 | `size.checkCircle` |
| 空心圈線寬 | `size.hairlineThick` —— 比 `hairline` 粗，**1px 在圓弧上會斷斷續續** |
| 勾號 | `icon.xs` ＋ `bold` |
| 最小寬度 | 固定，不壓縮 |

**觸控目標是列不是這個圓**：22pt 遠小於 44pt 的最小觸控。列必須整條可點。

## 6 配色 ★

| 狀態 | 底 | 圈線 | 勾號 |
|---|---|---|---|
| selected | `actionPrimary` | 無 | `surfaceBase` |
| unselected | 透明 | `neutral-400` | 無 |

## 7 文字行為

無文字。**Dynamic Type**：不跟隨（它是圖示）。

## 8 動態

目前無轉場。**已知缺口**：selected 與 unselected 之間直接切換沒有動畫，
在清單裡連點兩項會顯得突兀。要補的話用 `motion.fast`。

## 9 無障礙

- **自己不掛 label 也不掛 trait**。選取狀態應該由列表達
  （`.accessibilityAddTraits(.isSelected)`），否則 VoiceOver 會念出兩個獨立的東西。
- 不掛 `accessibilityIdentifier` —— 測試定位的是列。

## 10 用法與禁用法

**用它**：清單裡「選一個／選多個」，而且選完不離開這一頁時。

**易混淆**：`TLChevron`（可進入的列）—— 這個表示**選取**，那個表示**進入下一層**。
同一列不該同時出現兩者：那會讓人不知道點下去是選還是進去。

**不要用它**：
- 當可點的按鈕 —— 22pt 不是合法觸控目標，要整列可點
- 跟 chevron 並存
- 表達「完成」之類的狀態 —— 它表達的是「被選中」，語意不同

## 11 組成 ★

N/A（L1 原子）。

## 12 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `TLListRow.swift` 拆成獨立檔 | 那個檔有 4 個 public 元件 |
| 2026-08-30 | 內部字面值 `22`／`1.5`／`11` 改成 token | 元件內部的字面值也是字面值。順帶新增 `size.hairlineThick` —— 圓弧上的線需要比 1px 粗 |
