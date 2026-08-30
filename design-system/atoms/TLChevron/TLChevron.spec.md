# TLChevron

## 1 身分

| | |
|---|---|
| 層級 | L1 原子 |
| 職責 | 可進入的列右側的指向記號 |
| 原型 id | 出現在所有可進入的列（`4b` `4c` `5b` `5c`） |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Atoms/TLChevron.swift` |
| Preview | `design-system/atoms/TLChevron/TLChevron.preview.html` |

## 2 介面 ★

**Props** — 無。

| 名稱 | 型別 | 必填 | 預設 | 說明 |
|---|---|---|---|---|
| （無） | | | | |

尺寸與顏色是固定的；**位置與間距由使用它的列負責**，不是這個元件的責任。
`TLSettingsRow` 就是這樣做的：`TLChevron().padding(.leading, trailingGap)`。

**Slots** — N/A（原子沒有子內容）
**事件** — N/A（不可互動；點擊由整列承接）

## 3 變體 variants

無。只有一種樣子。

## 4 狀態 states ★

<!-- states: default, light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **只有 default。** pressed 由整列表現（列有自己的按下態），chevron 本身不變 |
| 選取 | selected / unselected / indeterminate | N/A — 它不表達選取 |
| 資料 | empty / loading / error | N/A — 沒有資料輸入 |
| 內容極值 | 最短 / 最長 / 溢出 / 數字最大位數 | N/A — 固定圖示，無內容 |
| 主題 | light / dark | **兩者都有。** 顏色走 `textTertiary`，深色接上時自動成立 |
| 語言 | 中文 / 英文 | N/A — 無文字。但**方向**受語系影響，見第 7 節 |

## 5 度量

| | |
|---|---|
| 字級 | 13pt semibold（SF Symbol 的視覺尺寸，非 token 角色字級） |
| 尺寸 | 由 SF Symbol 決定，不設 frame |
| 內距 | 無 —— 由使用它的列給 |

## 6 配色 ★

| 用途 | token |
|---|---|
| 記號本身 | `textTertiary` |

## 7 文字行為

無文字。

**方向性**：SF Symbol 的 `chevron.right` 在 RTL 語系會自動鏡射。App 目前只有中／英（皆 LTR），
所以不影響，但**不要改用固定方向的自繪箭頭**，那會讓未來加入 RTL 語系時默默壞掉。

**Dynamic Type**：目前固定 13pt，不跟隨。C7a 決定支援範圍時，它應該跟著 `rowTitle` 一起縮放
（它是列的一部分，單獨縮放會和主標對不齊）。

## 8 動態

無轉場、無動畫、無觸覺回饋。整列的按下態由列自己處理。

## 9 無障礙

- **不需要 accessibility label** —— 它是純裝飾，語意由整列承載。
  列本身應該有 `.accessibilityAddTraits(.isButton)`。
- 不掛 `accessibilityIdentifier` —— 測試定位的是列，不是箭頭。
- 最小觸控：N/A（不可互動）。

## 10 用法與禁用法

**用它**：列可以進入下一層時。

**不要用它**：
- 表達展開／收合 —— 那要的是會旋轉的記號，不是這個
- 當作裝飾放在不可進入的列上 —— 那會騙使用者
- 自己加 padding 到元件裡 —— 間距是列的責任

## 11 組成 ★

N/A（L1 原子）。

## 12 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `TLListRow.swift` 抽出成獨立檔 | 原本埋在分子檔裡，沒有地址，無法單獨交付給設計端 |
| 2026-08-30 | 顏色從 `neutral500` 改成 `textTertiary` | 值相同（兩者都指向色階層的 `neutral.500`），改用語意層才有深色的位置 |
| 2026-08-30 | **規格字級訂為 13pt，不是 16pt** | 設計文件 `11-component-inventory.md` 與原本的 doc comment 都寫「16pt bold」，但程式碼從來都是 13pt semibold。以**實作為準**——16pt 在 15pt 的列主標旁邊會比主標還大，明顯不對。設計端的清單要更正 |
