# TLPillButton

## 1 身分

| | |
|---|---|
| 層級 | L1 原子 |
| 職責 | 填色的小膠囊鈕 |
| 原型 id | `11c` `13c` |
| 獨立使用 | 是（但它預設坐在有色底上，見第 7 節） |
| 容器責任 | 與相鄰鈕的間距由容器負責 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Atoms/TLPillButton.swift` |
| Preview | `design-system/atoms/TLPillButton/TLPillButton.preview.html` |
| Preview CSS | `components.preview.css` §TLPillButton |

**組成**：不由其他 `TL*` 元件組成。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `title` | `Text` | | 是 | — | 鈕上的字 |
| `tint` | `Color` | 只吃語意 token | 否 | `accent-700` | 文字色。底一律是 `surfaceBase` |
| `width` | `Width` | `hug` / `fill` | 否 | `hug` | 見第 3 節 |
| `action` | `() -> Void` | | 是 | — | 按下 |

**Slots** — N/A
**事件** — `action`

## 3 變體 variants

| `width` | 寬度 | 上下內距 | 用在哪 |
|---|---|---|---|
| `hug` | 跟著內容 | `space.pillPadV` 8 | 輸入色帶的快捷鍵（一排並列） |
| `fill` | 撐滿可用寬度 | `space.pillPadVWide` 10 | 休息畫面的預設秒數（格狀排列） |

⚠ **兩者的上下內距差 2px。** 同一顆鈕的兩種寬度該不該有不同的高度，
是膠囊幾何那組待決問題的一部分 —— 先如實保留兩個值，不自己收。

## 4 狀態 states ★

<!-- states: hug, fill -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | default。**沒有按下態的視覺**（`.plain` 樣式）—— 它坐在有色底上，加底色回饋會糊掉 |
| 選取 | selected / unselected / indeterminate | N/A —— 它是動作不是選項 |
| 資料 | empty / loading / error | N/A |
| 內容極值 | 最短 / 最長 / 溢出 | `hug` 跟著內容長；`fill` 等分容器，字太長會截斷 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 英文較長，`hug` 的一排在英文可能換行 |

## 5 度量與行為

| | |
|---|---|
| 字級 | `type.buttonLabelSmall` ＋ `semibold` |
| 左右內距 | `space.pillPadH` |
| 上下內距 | 見第 3 節 |
| 形狀 | `radius.pill` |
| 底 | `surfaceBase` |

### 動態

無。

## 6 配色 ★

| 用途 | token |
|---|---|
| 底 | `surfaceBase` |
| 文字 | 預設 `accent-700`；休息畫面用 `accent-800`（那個底更深） |

## 7 用法與禁用法

**用它**：坐在**有色底**上的小動作 —— 休息畫面的秒數、輸入色帶的快捷鍵。

**易混淆**：`.tlSecondarySmall` 按鈕樣式 —— 那個是**線框**。
判準：**它坐在什麼上面？** 坐在頁面底上用線框，坐在色塊上用這個。

**不要用它**：
- 當頁面級的主要動作 —— 那是 `.tlPrimary`，這顆太小
- 放在白底上 —— 它的底就是 `surfaceBase`，會消失

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-09-04 | 新增 | `ActiveWorkoutView` 裡有 **`restPill` 與 `quickPill` 兩份實作**，只差 2px 內距與一階文字色。兩份實作就是漂移本身 |
| 2026-09-04 | 兩種寬度保留兩個上下內距 | 收成一個是**視覺決定**，屬於膠囊幾何那組待決問題 —— 我只收實作，不收像素 |
