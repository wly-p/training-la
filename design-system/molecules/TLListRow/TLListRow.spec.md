# TLListRow

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 資料清單的一列 |
| 原型 id | `4c` `5b` `12c` `12d` `14c` |
| 獨立使用 | **否 —— 必須置於 `TLGroup` 之內** |
| 容器責任 | 圓角、底色、分隔線由 `TLGroup` 負責 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLListRow.swift` |
| Preview | `design-system/molecules/TLListRow/TLListRow.preview.html` |
| Preview CSS | `components.preview.css` §TLListRow |

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `title` | `Text` | | 是 | — | 列名 |
| `subtitle` | `Text?` | | 否 | `nil` | 第二行。**內容是「組成摘要」**，見第 7 節 |
| `equipment` | `String?` | | 否 | `nil` | 標題右側的小標。⚠ 用途已收窄，見第 12 節 |
| `showChevron` | `Bool` | | 否 | `false` | 是否通往下一層 |
| `onTap` | `(() -> Void)?` | | 否 | `nil` | 點整列。`nil` ＝ 不可點 |

**Slots** — `leading`（左側，通常放 `TLBadge` 或 `TLCheckCircle`）、
`detail`（標題下方的細節行，放得下非文字元素）、
`trailing`（右側，通常放 `TLRowValue`）。
**事件** — `onTap`

**`subtitle` 與 `detail` 擇一**：前者是純文字第二行，後者放得下 pill 這類元素。
同時用會有兩行第二內容，那沒有設計。

## 3 變體 variants

無變體，但**有三種填法**：

| 填法 | 組成 |
|---|---|
| 圖示型 | `leading` 放 `TLBadge` ＋ 主副標 ＋ `trailing` 放 `TLRowValue` ＋ chevron |
| 純文字型 | 主標 ＋ `trailing` |
| 可勾選型 | `leading` 放 `TLCheckCircle` ＋ 主副標，**沒有 chevron** |

## 4 狀態 states ★

<!-- states: default, pressed, selectable, withDetail -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **default 與 pressed。** `onTap` 為 `nil` 時不可點。沒有 disabled —— 目前清單沒有「這一項不能選」的情境 |
| 選取 | selected / unselected / indeterminate | 由 `leading` 放的 `TLCheckCircle` 表達，**不是這個元件的 prop**。⚠ 這代表列自己不知道自己被選中了，`accessibilityAddTraits(.isSelected)` 要呼叫端加 —— 見第 9 節 |
| 資料 | empty / loading / error | N/A —— 沒有資料就不會有這一列 |
| 內容極值 | 最短 / 最長 / 溢出 | 標題可換行；`trailing` 與 `leading` 不縮 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 副標是「組成摘要」，中英長度差最大的就是它 |

## 5 度量

| | |
|---|---|
| 列高 | 有 `detail`：`size.rowWithDetail`；有 `subtitle`：`size.rowWithSub`；否則 `size.row`。皆為 `minHeight` |
| 左右內距 | `space.rowInset` |
| 標題字級 | `type.rowTitle` |
| 標題與副標之間 | `space.titleSubGap` |
| 最小寬度 | 標題可壓到換行；leading 與 trailing 不縮 |
| 壓縮行為 | **標題與副標先讓**，兩側固定 |

## 6 配色 ★

| 用途 | token |
|---|---|
| 標題 | `textPrimary` |
| 副標 | `textSecondary` |
| 按下態底色 | `textPrimary` @ 6% |

## 7 文字行為

**副標的內容規則**：`subtitle` 永遠是**組成摘要** —— 清單裡的每一項列出它由什麼組成。這是階層關係唯一的傳達管道，
所以不要拿它放狀態或時間。**狀態一律放右側。**

**溢出**：標題與副標都可換行。

**多語系寬度**：副標是全 app 中英落差最大的文字（一串名稱的連接）。

**Dynamic Type**：應跟隨。

## 8 動態

按下時底色淡入，`motion.fast`。無縮放。

## 9 無障礙

- `onTap` 不為 `nil` 時列有 button trait。
- ⚠ **可勾選型的 selected trait 要呼叫端自己加**。這個元件不知道 `leading` 裡放的是
  `TLCheckCircle` 還是 `TLBadge`，所以無法自動判斷。
  **這是一個介面設計上的缺口** —— 見第 12 節。
- `accessibilityIdentifier` 由呼叫端加。

## 10 用法與禁用法

**用它**：資料清單的列。

**易混淆**：`TLSettingsRow`（設定列）—— 那個沒有圓章、右側是「目前的值」，用在**設定**；
這個有圓章與副標、可選取，用在**資料清單**。看到圓章就是這個。

**不要用它**：
- 同時用 `subtitle` 與 `detail` —— 兩行第二內容沒有設計
- 把狀態放進副標 —— 狀態一律放右側，副標是組成摘要
- chevron 與 `TLCheckCircle` 並存 —— 點下去是選還是進去會分不清

## 11 組成 ★

由 `TLChevron`（L1）組成；slot 常放 `TLBadge`／`TLCheckCircle`／`TLRowValue`（皆 L1）。

## 12 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從四合一的 `TLListRow.swift` 拆出 | 那個檔有 4 個 public 元件 |
| 2026-08-30 | 副標間距 `2` 改成 `space.titleSubGap` | 元件內部的字面值也是字面值 |
| 2026-08-30 | **記錄 `equipment` 的用途已收窄** | 原本是「動作名右側的器材小標」，但動作庫（`18b`）與範本（`19a`）已經不走這條 —— 器材在那兩處是尾欄／細節行。現在只剩訓練中、預覽 sheet、歷史詳情、能力值四個位置在用 |
| 2026-08-30 | **記錄選取狀態的介面缺口** | 選取由 `leading` 裡放什麼決定，所以列自己不知道自己被選中，無障礙的 selected trait 要呼叫端補。**比較好的介面是加一個 `isSelected: Bool?` prop**，讓元件自己決定要不要放勾號、也能自動加 trait。那是介面改動，會動到所有呼叫端，留給撞到它的階段（階段 2 有四個選取清單） |
