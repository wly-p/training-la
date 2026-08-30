# TLValuePicker

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 從一組常用數值裡選一個（滾輪） |
| 原型 id | `13a` `14c`；級距設定子頁 |
| 獨立使用 | 是 |
| 容器責任 | 自己負責滾輪與快捷列的內部排版；外部間距由畫面給 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLValuePicker.swift` |
| Preview | `design-system/molecules/TLValuePicker/TLValuePicker.preview.html` |

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `value` | `Binding<Double>` | | 是 | — | 目前的值 |
| `values` | `[Double]` | | 是 | — | 可選的常用值。**滾輪只放常用值**，其餘靠呼叫端另外提供輸入 |
| `kicker` | `String?` | | 否 | `nil` | 滾輪上方的小標，通常放單位 |
| `format` | `(Double) -> String` | | 否 | 預設格式化 | 怎麼把數字變成顯示字串 |
| `quickActions` | `[QuickAction]` | | 否 | `[]` | 滾輪下方的快捷按鈕 |

**Slots** — N/A
**事件** — 透過 `value` binding 回寫；`QuickAction` 各自帶 `action`

## 3 變體 variants

無變體，但**有沒有 `quickActions` 會改變高度**：有的話滾輪下方多一列
`size.quickActionRow`。

## 4 狀態 states ★

<!-- states: idle, dragging -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **idle 與 dragging。** 拖曳時中間那格跟著換值。沒有 disabled |
| 選取 | selected / unselected / indeterminate | **中間那格永遠是選中的值** —— 位置即選取，不需要額外記號 |
| 資料 | empty / loading / error | ⚠ `values` 為空時滾輪是空的。呼叫端應保證非空 |
| 內容極值 | 最少 / 最多值 | 值少於 5 個時上下會留白（滾輪固定顯示 5 格）；值很多時靠拖曳，沒有上限 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 數字本身不變；`kicker` 與 `QuickAction` 的文案會變 |

## 5 度量

| | |
|---|---|
| 滾輪與 kicker 之間 | `space.pickerGap` |
| 每一格高度 | 由滾輪幾何決定（`WheelGeometry`） |
| 可見格數 | 5（中間為選中） |
| 快捷列高度 | `size.quickActionRow`（＝最小觸控） |
| 快捷 chip 內距 | `space.chipPadV` |
| 快捷 chip 外框 | `size.hairline` |

**滾輪的幾何是純函式**（`Support/CalendarStripGeometry` 與 `WheelGeometry`），
所以可以單獨單元測試 —— 這是元件庫裡少數測得動的部分。

## 6 配色 ★

| 用途 | token |
|---|---|
| 選中值 | `textNumeric` |
| 鄰近值 | `textSecondary` |
| 遠端值 | `textTertiary`（並降低不透明度） |
| kicker | `textTertiary` |
| 快捷 chip 外框 | `textPrimary` @ 10% |

## 7 文字行為

數字用 display 家族（Caprasimo）。`format` 由呼叫端決定小數位數 ——
元件不做格式化，因為「幾位小數」是領域知識（重量 vs 秒數不同）。

**Dynamic Type**：滾輪的格高與字級綁在一起，放大需要重算幾何。**這是階段 C7a 最難的一項。**

## 8 動態

拖曳結束後**滾到最近的一格**（settle），時長依距離遞增但有上限 ——
那個曲線是 `WheelGeometry.settleDuration` 算的，有單元測試釘住。

## 9 無障礙

- ⚠ **這是目前無障礙最弱的元件**：滾輪是自繪的，VoiceOver 沒有原生 picker 的語意。
  正確做法是包成 `adjustable` trait ＋ increment/decrement 動作。**尚未實作。**
- `QuickAction` 是一般按鈕，label 就是它的文案。

## 10 用法與禁用法

**用它**：從一組**常用**數值裡選一個。

**易混淆**：`TLNumberField`（直接打字輸入）—— 滾輪適合「常用值就那幾個」，
打字適合「任意值」。**兩者常常要並存** —— 級距設定頁就是滾輪 ＋ 自訂輸入列，
因為實際器材的級距不一定落在常用值上。
> 體檢 P1-4 指出訓練中記錄重量只有滾輪、沒有打字，2.5kg 級距從 20 滑到 140 要滑 48 格。
> 那張票（`記錄畫面數值輸入改成打字為主`）就是要補這個。

**不要用它**：
- 值域很大又連續 —— 滑不完，用打字
- 只有 2–3 個選項 —— 用 `TLSegmentedControl`
- 當唯一的輸入方式 —— 常用值以外的情況要有出口

## 11 組成 ★

不由其他 `TL*` 元件組成（自繪滾輪 ＋ 快捷 chip）。

## 12 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `Components/` 移到 `Molecules/` | 分層落地 |
| 2026-08-30 | 內部字面值 `16`／`12`／`1`／`44` 改成 token | 元件內部的字面值也是字面值 |
| 2026-08-30 | **記錄無障礙缺口** | 自繪滾輪沒有 `adjustable` trait，VoiceOver 使用者無法調整。這不是這一輪造成的，但寫規格第 9 節時才被明確記下來 |
