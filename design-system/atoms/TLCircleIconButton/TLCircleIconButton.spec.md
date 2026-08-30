# TLCircleIconButton

## 1 身分

| | |
|---|---|
| 層級 | L1 原子 |
| 職責 | 圓形的圖示按鈕 |
| 原型 id | `4c`（標題右側的＋）、月曆標題列的 `‹ ›`、drill-in 子頁的返回 |
| 獨立使用 | 是 —— 它自己就是一個完整的觸控目標 |
| 容器責任 | 與相鄰元素的間距由放它的列或列容器負責 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Atoms/TLCircleIconButton.swift` |
| Preview | `design-system/atoms/TLCircleIconButton/TLCircleIconButton.preview.html` |

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `systemImage` | `String` | | 是 | — | SF Symbol 名稱 |
| `style` | `Style` | `accent` / `outline` / `neutral` | 否 | `accent` | 材質。見第 3 節 |
| `size` | `CGFloat` | 只吃 `size.*` token | 否 | `size.iconButton` | 整顆的直徑 |
| `iconSize` | `CGFloat` | 只吃 `icon.*` token | 否 | `icon.button` | 圖示字級 |
| `iconWeight` | `Font.Weight` | | 否 | `semibold` | 圖示字重 |
| `action` | `() -> Void` | | 是 | — | 點擊 |

**Slots** — N/A（內容固定是一個 SF Symbol）
**事件** — `action`（見上）

## 3 變體 variants

| 變體 | 說明 |
|---|---|
| `accent` | 赭紅實心、淺色圖示。主要動作 |
| `outline` | 線框、赭色圖示。次要動作（返回、關閉） |
| `neutral` | `surfaceTrack` 實心、深墨圖示。月曆標題列的 `‹ ›` 用 —— 與「今天」膠囊同材質，導航鍵不跟狀態搶顏色 |

三個變體的 pressed 態都是整顆縮放，沒有變體專屬的差異。

## 4 狀態 states ★

<!-- states: default, pressed -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **default 與 pressed。** 沒有 disabled —— 目前所有使用情境都永遠可用；真的需要時要先補設計 |
| 選取 | selected / unselected / indeterminate | N/A —— 它是動作不是選項 |
| 資料 | empty / loading / error | N/A —— 沒有資料輸入 |
| 內容極值 | 最短 / 最長 / 溢出 / 數字最大位數 | N/A —— 內容固定是一個圖示 |
| 主題 | light / dark | 三個變體的底色與圖示色都走語意 token |
| 語言 | 中文 / 英文 | N/A —— 無文字。**但無障礙標籤必須由呼叫端給** |

## 5 度量

| | |
|---|---|
| 直徑 | `size.iconButton`（＝最小觸控 44）；月曆導航用 `size.iconButtonSmall`，觸控區另外補到 44 |
| 圖示 | `icon.button` ＋ `semibold` |
| 內距 | 無 —— 圖示置中 |
| 最小寬度 | 固定，不壓縮 |
| 壓縮行為 | 永遠保持原尺寸；空間不夠時先讓的是它旁邊的東西 |

## 6 配色 ★

| 變體 | 底 | 圖示 |
|---|---|---|
| `accent` | `actionPrimary` | `surfaceBase` |
| `outline` | 透明 ＋ `accentOnSurface` 外框 | `accentOnSurface` |
| `neutral` | `surfaceTrack` | `textPrimary` |

## 7 文字行為

無文字。

**Dynamic Type**：**不跟隨**。它是固定的觸控目標，跟著字級長大會把標題列撐爛。

## 8 動態

按下時整顆縮放，時長 `motion.fast`、曲線 `motion.curve`。無觸覺回饋。

## 9 無障礙

- **必須由呼叫端給 accessibility label** —— 元件本身只知道 SF Symbol 名稱，那不是可讀的名字。
  少寫的話 VoiceOver 會念出符號名或什麼都不念。
- 直徑預設 `size.iconButton` ＝ 44，已滿足最小觸控。用 `size.iconButtonSmall` 時**呼叫端要自己把觸控區補到 44**。
- `accessibilityIdentifier` 由呼叫端加（測試要定位的是「哪一個按鈕」，元件不知道）。

## 10 用法與禁用法

**用它**：需要一個只有圖示、沒有文字的圓形動作時。

**易混淆**：`TLIconThumbnail`（列裡的方形圖片預覽）—— 這個是**可點的動作**，那個是唯讀的縮圖。

**不要用它**：
- 放文字進去 —— 它是圖示按鈕，文字動作用文字按鈕樣式
- 用 `size.iconButtonSmall` 卻不補觸控區 —— 那會做出 34pt 的觸控目標
- 用 `accent` 當次要動作 —— 一個畫面最多一個主要動作區

## 11 組成 ★

N/A（L1 原子）。

## 12 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `Support/ButtonStyles.swift` 抽出成獨立檔 | 它是 View 不是 ButtonStyle，卻和 8 個 `ButtonStyle` 住同一個檔。第一輪就記進已知缺口了 |
| 2026-08-30 | `iconSize` 的預設從字面 `18` 改成 `icon.button` | 元件內部的字面值也是字面值。⚠ 順帶發現 icon 尺度有 **13/14/16/18/20 五個特設值**，彼此沒有比例關係——這已經不是尺度，見 `CHANGELOG.md` 已知缺口 |
| 2026-08-30 | `init(systemImage:filled:action:)` 標為舊 API，新程式碼用 `style:` | 那個 init 的註解自己寫著「舊呼叫端相容」。全專案還有 3 處在用，之後順手換掉 |
