# TLToggle

## 1 身分

| | |
|---|---|
| 層級 | L1 原子 |
| 職責 | 開關（switch） |
| 原型 id | `4b` `12a` |
| 獨立使用 | **否 —— 它是 `ToggleStyle`，套在 SwiftUI 的 `Toggle` 上** |
| 容器責任 | 位置與間距由列負責 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Atoms/TLToggle.swift` |
| Preview | `design-system/atoms/TLToggle/TLToggle.preview.html` |
| Preview CSS | `components.preview.css` §TLToggle |

**實作形式與其他原子不同**：它是 `ToggleStyle` 而不是 `View`，用法是
`Toggle(...).toggleStyle(.tlSwitch)`。這是刻意的 —— 見第 9 節。

## 2 介面 ★

**Props** — 無。

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| （無） | | | | | |

開／關狀態由 `Toggle` 的 binding 提供，不是這個樣式的 prop。

**Slots** — N/A（`configuration.label` 由 `Toggle` 給）
**事件** — N/A（`Toggle` 的 binding 負責）

## 3 變體 variants

無。

## 4 狀態 states ★

<!-- states: on, off -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **on 與 off。** 沒有獨立的 pressed —— 點下去就切換，旋鈕滑過去即是回饋。**沒有 disabled**：⚠ 這是實際的缺口，見 `TLSettingsToggleRow` 第 12 節 |
| 選取 | selected / unselected / indeterminate | 開／關就是它的意義；沒有 indeterminate（SwiftUI 的 `Toggle` 也不支援） |
| 資料 | empty / loading / error | N/A |
| 內容極值 | 最短 / 最長 / 溢出 | N/A —— 固定尺寸 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | N/A —— 無文字（label 由 `Toggle` 給，屬於列） |

## 5 度量

| | |
|---|---|
| 軌道 | `size.switchW` × `size.switchH` |
| 圓角 | `radius.pill` |
| 旋鈕內距 | `space.switchKnobInset`（旋鈕直徑 ＝ 軌道高 − 2×內距） |

## 6 配色 ★

| 狀態 | 軌道 | 旋鈕 |
|---|---|---|
| on | `actionPrimary` | `surfaceBase` |
| off | `surfaceInput` | `surfaceRaised` |

**不可以用系統 `Toggle` 的預設綠** —— 那會讓整頁瞬間變回原生。
這是設計原則裡明列的禁令之一。

## 7 文字行為

無文字。**Dynamic Type**：不跟隨。它是固定的控制項，跟著字級長大會把列撐爛。

## 8 動態

切換時旋鈕滑到另一端，`motion.base` ＋ `motion.curve`。軌道底色同時轉換。

## 9 無障礙

**做成 `ToggleStyle` 而不是自繪 Button，整個原因就在這裡**：

- 底層仍是 `Toggle`，所以 VoiceOver 會念「開關，已開啟／已關閉」而不是「按鈕」
- XCUITest 認得 `.switches`，而且 value 是 `"1"`／`"0"` —— 自繪的話這些全部要自己補，
  而且很容易補不完整

**只換外觀、不換語意**，是這個元件唯一的設計目的。

## 10 用法與禁用法

**用它**：`Toggle(...).toggleStyle(.tlSwitch)`。設定頁請直接用 `TLSettingsToggleRow`，
它已經包好了。

**易混淆**：`TLCheckCircle`（清單裡的選取記號）—— 開關表達「這個功能開著嗎」，
勾號表達「這一項被選了嗎」。前者是設定，後者是選擇。

**不要用它**：
- 自繪一個看起來一樣的按鈕 —— 會失去 switch 的無障礙語意與測試可定位性
- 用系統預設樣式 —— 見第 6 節
- 拿它表達「選中」—— 那是 `TLCheckCircle`

## 11 組成 ★

N/A（L1 原子）。

## 12 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `Components/` 移到 `Atoms/` | 分層落地。設計文件本來就把它列為 L1（`TLSwitch`） |
| 2026-08-30 | 顏色改用語意 token（`actionPrimary`／`surfaceInput`／`surfaceBase`／`surfaceRaised`） | 才有深色的位置 |
| 2026-08-30 | **動畫 `0.18` 收斂到 `motion.base`(0.2)** | 那是全專案唯一的落單動畫值，第一輪就記進 token 的 `_note` 說「收斂前不要新增第四個值」。0.02 秒的差異不可感知，而多一個值就是多一份要維護的分歧 |
