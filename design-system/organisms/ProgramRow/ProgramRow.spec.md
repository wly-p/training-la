# ProgramRow

## 1 身分

| | |
|---|---|
| 層級 | L3 有機體 |
| 職責 | 長期課表清單的一列 |
| 原型 id | `8a` |
| 獨立使用 | 啟用態是一張卡，**不必放進 `TLGroup`**；未啟用態是列，必須放進 `TLGroup` |
| 容器責任 | 未啟用態的圓角、底色、分隔線由 `TLGroup` 負責；啟用態的卡自己有外框 |
| 實作 | `Packages/Plan/Sources/PlanPresentation/Components/ProgramRow.swift` |
| Preview | `design-system/organisms/ProgramRow/ProgramRow.preview.html` |
| Preview CSS | `components.preview.css` §ProgramRow |

**組成**：`TLRowContent`（L2）＋ `TLBadge`（L1）＋ `TLProgressBar`（L1）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `id` | `UUID` | | 是 | — | drill-in 的目的地。兩種形態都用得到 |
| `name` | `String` | | 是 | — | 課表名 |
| `summary` | `Text` | | 是 | — | 副標＝組成摘要 |
| `progress` | `Progress?` | | 是 | — | **`nil` ＝ 未啟用形態。** 有值就是卡片形態 |
| `activateButton` | `AnyView?` | | 是 | — | 未啟用態右側的「啟用」鈕；啟用態不用 |
| `dayUnit` | `Text` | | 是 | — | 「N / M 天」的單位字。由呼叫端給 —— 它才對得到 String Catalog |
| `todayLabel` | `Text` | | 是 | — | 「今天：」的前綴。同上 |
| `menu` | `AnyView` | | 是 | — | 長按選單。兩種形態都有 |

`Progress` ＝ `day` / `totalDays` / `todayWorkoutName?`。

**Slots** — N/A
**事件** — 無自己的事件（drill-in 走 `NavigationLink(value:)`，動作在 `menu` 與 `activateButton` 裡）

## 3 變體 variants

| 變體 | 說明 |
|---|---|
| 啟用（`progress != nil`） | **一張卡**：accent 描邊 ＋ 上半可 drill-in ＋ 下半是進度（天數／今天／進度條） |
| 未啟用（`progress == nil`） | 一般列：左側可 drill-in、右側 inline「啟用」，**兩個獨立的點擊區** |

**兩種形態的差別比 `RotationRow` 大** —— 那個兩種都是列，這個換了容器。

## 4 狀態 states ★

<!-- states: active, inactive -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | 卡的上半可點、未啟用列的左右各自可點。**沒有整列 pressed 底色** —— 可點的是區塊不是整列 |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | 今天沒有排課時顯示「—」，那是**內容**不是狀態 |
| 內容極值 | 最短 / 最長 / 溢出 | 名稱與摘要一行截斷；天數與進度條不縮 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 「今天：」那一行在英文明顯長，與左側天數競爭同一行 |

## 5 度量與行為

| | |
|---|---|
| 卡的內距 | `space.rowInset`（四邊） |
| 卡內各段間距 | `space.gapM` |
| 卡的外框 | `radius.container` ＋ `size.hairlineThick` 描邊 |
| 天數字級 | `type.cardNumber`（display 家族） |
| 天數與單位之間 | `space.numberUnitGap` |
| 進度條 | `size.progressBar` 高 |
| 未啟用列 | 左右 `space.rowInset`、最小高度 `size.rowWithSub` |

**上半用 `TLRowContent` 而不是 `TLListRow`** —— 卡片自己有 padding、只有上半可點，
列的外框（內距、最小高度、整列 Button）全都不適用。這就是拆出 `TLRowContent` 的原因。

### 文字與溢出

名稱與摘要各一行截斷。「今天：」那一行靠右，與左側天數共用一行。

### 動態

進度條無動畫（值變化時直接跳）。

## 6 配色 ★

| 用途 | token |
|---|---|
| 卡底 | `surfaceRaised` |
| 卡描邊 | `accent-300` |
| 圓章（啟用／未啟用） | `actionPrimary` ／ `neutral-300` |
| 天數 | `textPrimary` |
| 單位 | `neutral-500` |
| 「今天：」 | `textSecondary` |
| 進度條軌道 | `surfaceTrack`（預設） |

⚠ 單位是 `neutral-500` 而不是語意 token —— 與 `TLRowContent` 副標同一個未遷移的殘留。

**這張卡用預設軌道**：卡底是 `surfaceRaised`（淺），預設的 `surfaceTrack` 就夠對比。
需要傳 `track` 的是長期課表**詳情頁**那張深底的卡 —— 它要往更淺的方向換。

## 7 用法與禁用法

**用它**：長期課表清單。

**易混淆**：`RotationRow` —— 那個兩種形態都是列；這個啟用後是卡。
判準：啟用後要不要顯示進度？要就是這個。

**不要用它**：
- 把啟用態的卡放進 `TLGroup` —— 卡自己有外框，會變成框中框
- 讓整張卡可點 —— 下半是進度資訊，點下去要去哪沒有答案

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 從 `ProgramListView` 抽出成 L3 | 階段 2 的分層落地 |
| 2026-08-31 | **驗證結果：這一個不能純由當時的 L2 組成 —— 架構賭注的答案在它身上** | 「進行中」卡原本**手工重建了整個 `TLListRow`**（圓章＋主副標＋chevron）。查下去不是偷懶，是**用不了**：`TLListRow` 把內容排版與列的外框綁在同一個型別，而這張卡有自己的 padding、只有上半可點。**分層是對的，錯的是那個分子的介面。** 拆出 `TLRowContent` 之後手工重建消失 |
| 2026-08-31 | `TLProgressBar` 抽成 L1，軌道色開成 prop | 兩處各自手工重建（`GeometryReader` ＋ 兩個 `Capsule`），只差軌道色。設計文件的 L1 清單本來就有它，只是實作沒有 |
