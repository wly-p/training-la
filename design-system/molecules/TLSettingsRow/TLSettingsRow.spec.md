# TLSettingsRow

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 設定頁的一列：一個名稱、一個目前的值、可能通往下一層 |
| 原型 id | `4b` |
| 獨立使用 | **否 —— 必須置於 `TLGroup` 之內** |
| 容器責任 | 圓角、底色、與相鄰列的分隔線由 `TLGroup` 負責 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLSettingsRow.swift` |
| Preview | `design-system/molecules/TLSettingsRow/TLSettingsRow.preview.html` |
| Preview CSS | `components.preview.css` §TLSettingsRow |

**組成**：由 `TLChevron`（L1）組成；trailing 通常放 `TLSettingsValue`（L1）或 `TLSegmentedControl`（L2）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `title` | `Text` | | 是 | — | 列名 |
| `hint` | `Text?` | | 否 | `nil` | 標題後方同一行的小灰字（短詞，如「含震動」） |
| `systemImage` | `String?` | | 否 | `nil` | 左側 SF Symbol。破壞性列用它放垃圾桶 |
| `role` | `Role` | `normal` / `destructive` | 否 | `normal` | 見第 3 節 |
| `showChevron` | `Bool` | | 否 | `false` | 是否通往下一層 |
| `trailingGap` | `CGFloat` | 只吃 `space.*` token | 否 | `space.gapS` | trailing 與 chevron 的間距 |
| `onTap` | `(() -> Void)?` | | 否 | `nil` | 點整列。`nil` ＝ 不可點 |

**Slots** — `trailing`：右側內容。放 `TLSettingsValue`（文字值）或 `TLSegmentedControl`（就地切換）。
**事件** — `onTap`

## 3 變體 variants

| 變體 | 說明 |
|---|---|
| `normal` | 一般列 |
| `destructive` | 破壞性操作。標題轉 `dangerOnSurface`、字重加粗、通常配左側垃圾桶圖示。**沒有 chevron** —— 它就地執行，不通往任何地方 |

## 4 狀態 states ★

<!-- states: default, pressed, tappable, static -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **default 與 pressed。** `onTap` 為 `nil` 時整列不可點（`static`）。**沒有 disabled** —— 目前設定頁沒有「暫時不能改」的列；真要做要先補設計（灰掉的列跟不可點的列看起來會一樣，那是問題） |
| 選取 | selected / unselected / indeterminate | N/A —— 選取是 `TLListRow` ＋ `TLCheckCircle` 的事 |
| 資料 | empty / loading / error | N/A |
| 內容極值 | 最短 / 最長 / 溢出 | 標題與 trailing 競爭同一行。**標題先讓** |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 英文標題與值都較長，同時變長時最容易擠 |

## 5 度量與行為

| | |
|---|---|
| 列高 | `size.row`（最小值，內容可撐高） |
| 左右內距 | `space.rowInset` |
| 標題字級 | `type.rowTitle` |
| 左側圖示 | `icon.inRow` ＋ `semibold`，右側留 `space.sectionHeaderGap` |
| 標題與 hint 之間 | `space.titleHintGap` |
| trailing 與 chevron 之間 | `trailingGap`（預設 `space.gapS`） |
| 最小寬度 | 標題可壓到換行；trailing 不縮 |
| 壓縮行為 | **標題先讓** —— 值是這一列的答案 |

**列高是 `minHeight` 不是固定值**：`TLSegmentedControl` 之類的 trailing 比文字高，
列會跟著長。`handoff-20` §B 把分段控制改矮就是為了讓它**不要**撐高這一列。

### 文字與溢出

**溢出**：標題可換行，不主動截斷。

**多語系寬度**：這是設定頁最容易出問題的地方 —— 英文的標題與值同時變長。
排版要用「最長英文標題 ＋ 最長英文值」檢查。

**Dynamic Type**：應跟隨。列高是 `minHeight` 所以放大不會裁切，但左右方向會更擠。

### 動態

按下時底色淡入，`motion.fast`。**沒有縮放** —— 列是大面積元素，縮放會很晃。

## 6 配色 ★

| 用途 | token |
|---|---|
| 標題（normal） | `textPrimary` |
| 標題（destructive） | `dangerOnSurface` |
| hint | `textTertiary` |
| 按下態底色 | `textPrimary` @ 6% |

## 7 用法與禁用法

**用它**：設定頁的列。

**易混淆**：`TLListRow`（列表列）—— 那個有圓章、副標、可選取，用在**資料清單**；
這個沒有圓章、右側是「目前的值」，用在**設定**。看到圓章就是 `TLListRow`。

**不要用它**：
- 開關列 —— 用 `TLSettingsToggleRow`，它底層是 `Toggle`，保留 `switches` 的測試可定位性
- destructive ＋ chevron 並存 —— 破壞性操作就地執行，不通往任何地方
- 放在 `TLGroup` 外面 —— 會失去圓角、底色與分隔線

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從三合一的 `TLSettingsRow.swift` 拆出 | 那個檔有 3 個 public 元件 |
| 2026-08-30 | 內部字面值 `17`／`15`／`10`／`6` 改成 token | 元件內部的字面值也是字面值 |
| 2026-08-30 | **`handoff-20` §B 要求的「我的能力值右側狀態值」尚未實作** | 那一列右側目前是空的。設計端確認**另開票**處理 —— 它是功能改動不是榨取，混進來會讓「視覺零變化」失去驗證能力 |
| 2026-08-31 | 左側圖示從 `type.rowIcon` 改成 `icon.inRow` | **它一直不是字級。**17 是 SF Symbol 的點數，卻住在字級群組裡，所以躲過了上一輪 icon 收斂。值沒變、群組換了。⚠ 若嚴格照「跟文字並排 → `icon.inline`」的判準它該是 14，那是 −3px、動到每一列設定的視覺改動，留給設計端拍板 |
