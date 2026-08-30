# TLInlineEmptyState

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 清單裡的空狀態：一句主文 ＋ 一句說明 |
| 原型 id | `4c` `5b` `5c` `5d` 的空清單 |
| 獨立使用 | 是 —— 直接放在清單原本的位置 |
| 容器責任 | 自己撐滿寬度與上下留白；左右邊距由畫面給 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLInlineEmptyState.swift` |
| Preview | `design-system/molecules/TLInlineEmptyState/TLInlineEmptyState.preview.html` |
| Preview CSS | `components.preview.css` §TLInlineEmptyState |

**組成**：不由其他 `TL*` 元件組成（純文字排版）

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `title` | `Text` | | 是 | — | 主句。呼叫端用 `localText` 建好再傳 |
| `hint` | `Text?` | | 否 | `nil` | 說明句。`nil` ＝ 只有主句 |

**Slots** — N/A
**事件** — N/A（沒有行動鈕 —— 那是 `TLEmptyState` 的事）

## 3 變體 variants

無。有沒有 `hint` 是有沒有傳 prop，不是變體。

## 4 狀態 states ★

<!-- states: default, titleOnly -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **不可互動** |
| 選取 | selected / unselected / indeterminate | N/A |
| 資料 | empty / loading / error | **它本身就是空狀態的呈現。** 不同的「為什麼空」由呼叫端換文案表達 |
| 內容極值 | 最短 / 最長 / 溢出 | 說明句會換行、置中；沒有行數上限 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 英文說明句明顯較長，兩行是常態 |

## 5 度量與行為

| | |
|---|---|
| 主句字級 | `type.emptyTitle` ＋ `bold` |
| 說明字級 | `type.emptyHint` ＋ `regular` |
| 兩者間距 | `space.emptyStateGap` |
| 上下留白 | `space.emptyStatePadV` |
| 寬度 | 撐滿，內容置中 |

### 文字與溢出

說明句 `multilineTextAlignment(.center)`，不截斷。主句預期是一行。

### 動態

無轉場。

## 6 配色 ★

| 用途 | token |
|---|---|
| 主句 | `textPrimary` |
| 說明 | `textSecondary` |

## 7 用法與禁用法

**用它**：清單空了，但頁面其他部分（標題、搜尋、分段控制）還在時。

**易混淆**：`TLEmptyState` —— 差別是**有沒有自己的容器**。
那個是一張卡（圓角容器 ＋ 圖示圓 ＋ 可選按鈕），用在**整頁皆空**；
這個是內嵌的，直接放在清單原本的位置。
判準：**畫面上還有別的東西嗎？** 有 → 用這個；沒有 → 用 `TLEmptyState`。

**不要用它**：
- 需要行動鈕時 —— 用 `TLEmptyState`
- 放在卡片裡 —— 它自己有上下留白，會跟卡片的 padding 疊起來
- 用同一份文案應付所有空的原因 —— 「搜尋無結果」與「還沒建立任何項目」是不同的事

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 從四個清單頁抽出 | `ExerciseListView`／`TemplateListView`／`RotationListView`／`ProgramListView` 各有一份**一字不差**的實作，只有文案不同 |
| 2026-08-31 | 字級 `16`／`12.5` 與間距 `8`／`40` 改成 token | 元件內部的字面值也是字面值。⚠ `TLEmptyState` 也用同樣的 16／12.5 字面值，那個檔還沒榨取到 |
