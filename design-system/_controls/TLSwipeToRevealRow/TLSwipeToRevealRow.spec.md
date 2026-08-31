# TLSwipeToRevealRow

> **控制項，不進交付包。** 它有狀態（拖曳位移）與手勢判斷，不是純呈現。
> 放在這裡是因為 L3 組合得到它 —— 元件庫的規格要能解釋 L3 是由什麼組成的。

## 1 身分

| | |
|---|---|
| 層級 | 控制項（`DesignControls`） |
| 職責 | 左滑露出**單一**動作的列 |
| 原型 id | `8b` |
| 獨立使用 | **否 —— 包在它裡面的內容才是列** |
| 容器責任 | 圓角與分隔線由 `TLGroup` 負責；它只負責露出與蓋住 |
| 實作 | `Packages/DesignControls/Sources/DesignControls/TLSwipeToRevealRow.swift` |
| Preview | `design-system/_controls/TLSwipeToRevealRow/TLSwipeToRevealRow.preview.html` |
| Preview CSS | `_controls/controls.preview.css` §TLSwipeToRevealRow |

**組成**：內容由呼叫端給（通常是 `TLListRow`）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `actionLabel` | `Text` | | 是 | — | 露出的動作文案 |
| `actionSystemImage` | `String` | | 是 | — | 露出的動作圖示（SF Symbol） |
| `actionTint` | `Color` | | 否 | `neutral-400` | 動作底色 |
| `actionForeground` | `Color` | | 否 | `surfaceBase` | 動作前景色 |
| `onAction` | `() -> Void` | | 是 | — | 按下露出的動作 |

**Slots** — `content`（被蓋住的那一列）
**事件** — `onAction`

## 3 變體 variants

無。**一次只露出一個動作** —— 兩個以上就變成需要記憶的選單，那是長按選單的工作。

## 4 狀態 states ★

<!-- states: closed, open -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | closed / open / dragging | 三種。拖曳中位移跟手，放開時吸附到全開或全關（過半即開） |
| 內容極值 | — | 動作區固定 88pt 寬，不隨文案長度變 |
| 主題 | light / dark | 兩者都有 |

## 5 度量與行為

| | |
|---|---|
| 動作區寬 | 88pt |
| 觸發門檻 | 拖曳 18pt 起算，且**水平位移要大於垂直位移** |
| 吸附 | 過半 → 全開；否則全關。`motion.base` easeOut |

**為什麼是普通 `.gesture` 而不是 `simultaneous`／`highPriority`**：
垂直捲動要歸 `ScrollView`、水平拖曳歸這裡、點擊歸內層的 `NavigationLink`。
搶優先權會把其中一個弄壞。

**內容自帶不透明底**：關閉時要完全蓋住底下的動作鈕，否則會透出一條色邊。

## 6 配色 ★

| 用途 | token |
|---|---|
| 動作底 | `neutral-400`（預設） |
| 動作前景 | `surfaceBase` |

**預設是灰的不是紅的**：這裡露出的是「停用」「複製」這類可回復的操作。
紅色留給真的刪掉的東西，而那類操作走長按選單 —— 需要更明確的意圖。

## 7 用法與禁用法

**用它**：清單列需要一個常用、單手可及的操作時。

**易混淆**：長按選單 —— 那個放低頻或破壞性的操作。
判準：這個操作一天會做幾次？常做才放左滑。

**不要用它**：
- 露出兩個以上的動作
- 放刪除 —— 刪除走長按選單
- 用在原生 `List` 裡 —— 那裡用 `.swipeActions`。這個是給 `TLGroup` 自訂容器用的

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 移進 `DesignControls` | 它有 `@State`（拖曳位移），不是純呈現 |
| 2026-08-31 | 補上規格 | 階段 2 的 `TemplateRow`／`RotationRow` 組合到它，**組成宣告要指得到一份規格**，否則「L3 由什麼組成」這句話沒有落點 |
