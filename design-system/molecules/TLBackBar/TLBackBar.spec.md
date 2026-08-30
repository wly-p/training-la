# TLBackBar

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | drill-in 子頁左上角的返回列 |
| 原型 id | 無 —— **這一層從來沒有設計稿**，見第 12 節 |
| 獨立使用 | 是 —— 它自己就是一個橫列，直接放在畫面最上方 |
| 容器責任 | 左右邊距與上邊距由這個元件自己負責；下方的間距由畫面給 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLBackBar.swift` |
| Preview | `design-system/molecules/TLBackBar/TLBackBar.preview.html` |
| Preview CSS | `components.preview.css` §TLBackBar |

**組成**：由 `TLCircleIconButton`（L1）組成。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `onBack` | `() -> Void` | | 是 | — | 點返回鈕 |

**Slots** — `trailing`：右側的操作區，預設空。某些子頁在這裡放一個文字操作（例：編輯）。
**事件** — `onBack`（見上）

## 3 變體 variants

無。**一個上邊距，兩頁共用。**

## 4 狀態 states ★

<!-- states: default -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **只有 default。** 按下態由 `TLCircleIconButton` 自己表現；這個容器不變 |
| 選取 | selected / unselected / indeterminate | N/A —— 它不表達選取 |
| 資料 | empty / loading / error | N/A —— 沒有資料輸入 |
| 內容極值 | 最短 / 最長 / 溢出 / 數字最大位數 | trailing 放太寬時會擠壓中間的空白，但返回鈕永遠保持原尺寸 |
| 主題 | light / dark | 兩者都有。自己沒有底色，顏色都來自 `TLCircleIconButton` |
| 語言 | 中文 / 英文 | 自己無可見文字；trailing 若放文字動作會受語言長度影響 |

## 5 度量與行為

| | |
|---|---|
| 左右邊距 | `space.page` |
| 上邊距 | `space.gapS` |
| 返回鈕 | `TLCircleIconButton` 的預設尺寸（`size.iconButton` ＝ 最小觸控） |
| 最小寬度 | 返回鈕 ＋ trailing 的寬度和；再窄就由 trailing 讓 |
| 壓縮行為 | 中間的 Spacer 先被壓掉；返回鈕不縮 |

### 文字與溢出

自己無文字。trailing 放文字動作時，中英長度差由該動作自己處理。

**Dynamic Type**：返回鈕不跟隨（它是固定觸控目標）；trailing 的文字應該跟隨。

### 動態

無轉場。返回鈕的按下態動畫由 `TLCircleIconButton` 提供。

## 6 配色 ★

自己沒有顏色。返回鈕用 `TLCircleIconButton` 的 `outline` 材質。

## 7 用法與禁用法

**用它**：drill-in 子頁需要一個返回入口時。

**易混淆**：`TLPageHeader`（頁面主標）—— 這個是**主標上方的導航列**，兩者通常上下相鄰但職責不同：
一個管「怎麼回去」，一個管「這是哪裡」。

**不要用它**：
- 當作 navigation bar 用 —— 它只有返回與一個動作，不是完整的工具列
- 在根層畫面用 —— 根層沒有「回去」，放了會騙使用者
- 把標題塞進 trailing —— 標題是 `TLPageHeader` 的事

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `SettingsSelectionView.swift` 與 `StepPreferenceView.swift` 抽出 | 同一個返回列在兩個畫面各寫一份 |
| 2026-08-30 | **加 `trailing` slot** | 抽的時候查到 `RotationDetailView` / `ProgramDetailView` 有同樣的返回列，但右側多一個「編輯」。不先留這個位置的話，階段 4 會回頭改這個元件 |
| 2026-08-30 | **統一成 `space.gapS`，不做變體**（設計端拍板） | 原本 12（選擇頁）與 8（級距頁）並存，而 12 沒有任何文件來源、8 剛好是 `gapS`。所以這題其實是「要不要為了 12 新增一個 token」，答案是不要。選 8 的理由：返回鈕是 44×44 觸控區、圓形視覺本體比觸控區小，**上緣本來就自帶留白**，再多給會把主標推得太低——主標與返回鈕該是同一個「頁面開頭」的單位。若實際看起來擠，正確解法是新增語意 token（例如 `space.screenTop`）兩頁一起用，不是把某一頁改回字面 12 |
| 2026-08-30 | 改用 `TLCircleIconButton` 的 `style:` API，不用 `filled:` | 那個 init 標了「舊呼叫端相容」。全專案還有 3 處在用，之後順手換掉 |
