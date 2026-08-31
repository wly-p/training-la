# TLCircleIcon

## 1 身分

| | |
|---|---|
| 層級 | L1 原子 |
| 職責 | 圓形圖示的**視覺**：固定直徑 ＋ 底色 ＋ 置中的 SF Symbol |
| 原型 id | `4a` `6b` `11c` |
| 獨立使用 | 是 |
| 容器責任 | 觸控區補到 `size.minTap` 是它自己做的 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Atoms/TLCircleIcon.swift` |
| Preview | `design-system/atoms/TLCircleIcon/TLCircleIcon.preview.html` |
| Preview CSS | `components.preview.css` §TLCircleIcon |

**組成**：不由其他 `TL*` 元件組成。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `systemImage` | `String` | | 是 | — | SF Symbol 名稱 |
| `style` | `Style` | `accent` / `outline` / `neutral` | 否 | `accent` | 見第 3 節 |
| `size` | `CGFloat` | | 否 | `size.iconButton` | 直徑。月曆導航用 `size.iconButtonSmall` |
| `iconSize` | `CGFloat` | | 否 | `icon.inIconButton` | 圖示點數。跟著容器直徑走的**配對值**，不是尺度階 |
| `iconWeight` | `Font.Weight` | | 否 | `.semibold` | 圖示字重 |

**Slots** — N/A
**事件** — **無。它不可點。**

## 3 變體 variants

| `style` | 底 | 圖示 | 用在哪 |
|---|---|---|---|
| `accent` | `actionPrimary` | `surfaceBase` | 頁首的主要動作（`+`） |
| `outline` | 透明 ＋ 細線框 | `accent-700` | 次要動作（返回） |
| `neutral` | `neutral-200` | `textPrimary` | 導航與「更多」。**赭色留給狀態**，導航不跟狀態搶顏色 |

## 4 狀態 states ★

<!-- states: accent, outline, neutral, small -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **一個都沒有** —— 它是視覺，互動歸 `TLCircleIconButton` |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | N/A |
| 內容極值 | 最短 / 最長 / 溢出 | 圖示置中，尺寸固定，不受內容影響 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 無關（沒有文字） |

## 5 度量與行為

| | |
|---|---|
| 直徑 | `size.iconButton`（月曆導航 `size.iconButtonSmall`） |
| 圖示 | `icon.inIconButton` |
| 形狀 | `radius.pill`（膠囊，正圓） |
| 觸控區 | 外圈補到 `size.minTap` |

**小尺寸（34pt）本身低於最小觸控**，所以外圈補到 44 才點得到；
`contentShape` 掛在補完的方框上，不是視覺的膠囊。

### 動態

無。按下回饋歸 `TLCircleIconButton`。

## 6 配色 ★

見第 3 節。線框的顏色是 `textPrimary` @ 18%。

## 7 用法與禁用法

**用它**：需要這個圓但**不是按鈕**的地方 —— 最典型的是 `Menu` 的 label。

**易混淆**：`TLCircleIconButton` —— 那個是 `Button` ＋ 這個。
判準：它自己要不要處理點擊？要就用那個。

**不要用它**：
- 自己包一層 `Button` —— 那正是 `TLCircleIconButton`，別重做一份
- 當狀態指示 —— 這個形狀在整套視覺裡代表「可以按」

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 從 `TLCircleIconButton` 拆出 | 課表頁的 `+` 是 **`Menu` 的 label 不是 `Button`**，而元件自己擁有 `Button`，所以那裡用不了它 —— 只能手工重畫一份圓（`ActiveWorkoutView` 也有一份）。**跟 `TLRowContent` 之於 `TLListRow` 是同一個錯誤**：把視覺與互動綁在同一個型別，不是按鈕的場合就得複製 |
