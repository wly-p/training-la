# TLSegmentedControl

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 就地切換「檢視」或在少數選項間選一個 |
| 原型 id | `4c` `7b` `11b`；設定列裡用 compact |
| 獨立使用 | 是（也常放在 `TLSettingsRow` 的 trailing） |
| 容器責任 | 自己負責軌道與內距；外部間距由放它的容器給 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLSegmentedControl.swift` |
| Preview | `design-system/molecules/TLSegmentedControl/TLSegmentedControl.preview.html` |
| Preview CSS | `components.preview.css` §TLSegmentedControl |

**組成**：不由其他 `TL*` 元件組成（軌道 ＋ 文字 ＋ 滑動膠囊）。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `selection` | `Binding<Value>` | | 是 | — | 目前選中的值 |
| `options` | `[Option]` | | 是 | — | 選項。每個是 `(value, label)` |
| `size` | `Size` | `regular` / `compact` | 否 | `regular` | 見第 3 節 |
| `identifierPrefix` | `String?` | | 否 | `nil` | 每段的 `accessibilityIdentifier` 前綴，第 n 段拿到 `<prefix>.<value>` |

**Slots** — N/A
**事件** — 透過 `selection` binding 回寫

## 3 變體 variants

| 變體 | 說明 |
|---|---|
| `regular` | 全寬，每段平分寬度。選中項有 `shadow.sm` |
| `compact` | 依內容寬。**選中項沒有陰影** —— 它放在設定列裡，陰影會讓它變成全頁最亮的東西 |

`compact` 的每一個數值都比 `regular` 小（軌道內距、段落內距、字級），
目的是**不撐高 `size.row` 的列**。

## 4 狀態 states ★

<!-- states: default, selected -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **沒有獨立的 pressed** —— 點下去就是選中，膠囊滑過去即是回饋。沒有 disabled：目前沒有「這個檢視暫時不能選」的情境 |
| 選取 | selected / unselected / indeterminate | **selected 與 unselected 是它的全部意義。** 永遠恰好一個被選中，沒有 indeterminate |
| 資料 | empty / loading / error | N/A —— 選項是靜態的 |
| 內容極值 | 2 段 / 多段 | 2–3 段最好。**4 段以上在 `compact` 會擠**，那時該考慮改用 drill-in 選擇頁 |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | `regular` 平分寬度所以最長的那段決定全體；`compact` 依內容寬，英文會整體變寬 |

## 5 度量與行為

| | | `regular` | `compact` |
|---|---|---|---|
| 軌道內距 | | `space.segTrackPad` | `space.segTrackPadCompact` |
| 段落上下內距 | | `space.segItemPadV` | `space.segItemPadVCompact` |
| 段落左右內距 | | 平分寬度 | `space.segItemPadH` |
| 字級 | | `type.rowTitle` | `type.segCompact` |
| 選中項陰影 | | `shadow.sm` | 無 |
| 圓角 | | `radius.pill` | `radius.pill` |

### 文字與溢出

**溢出**：不截斷。段落太多或文字太長時整個元件變寬，由容器決定怎麼辦。

**多語系寬度**：這是它最脆弱的地方。中文「公斤／磅」是兩字，英文 `kg`/`lb` 反而更短，
但「依日期／依動作」對 `By date`/`By exercise` 就反過來。**要用最長的語言排版。**

**Dynamic Type**：應跟隨，但 `compact` 已經很緊，放大後可能需要改成換行或退回 drill-in。

### 動態

切換時選中膠囊**滑動**過去（`motion.base` ＋ `motion.curve`），不是淡入淡出。
滑動讓人看得到「從哪換到哪」。

## 6 配色 ★

| 用途 | token |
|---|---|
| 軌道 | `surfaceTrack` |
| 選中項底 | `surfaceBase` |
| 選中項文字 | `textPrimary`（weight 700） |
| 未選文字 | `textSecondary`（weight 500） |

## 7 用法與禁用法

**用它**：切換**檢視**（依日期／依動作），或在 2–3 個值之間就地選一個。

**易混淆**：`TLChipRow`（選一個值的 chip 列）—— chip 是「選一個**值**」（總長度、強度基準），
seg 是「切換**檢視**」。視覺也不同：chip 選中是 accent 實心，seg 選中是白底膠囊。
> ⚠ `TLChipRow` 目前不在元件庫裡（設計文件列了但實作沒有），等撞到它的階段再處理。

**不要用它**：
- 超過 4 段 —— 改用 drill-in 選擇頁
- 段落文字長度差很多 —— `regular` 平分寬度會讓短的那段留一大片空白
- 在 `TLSettingsRow` 裡用 `regular` —— 會撐高列，`handoff-20` §B 就是為了修這個才加 compact

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-30 | 從 `Components/` 移到 `Molecules/` | 分層落地 |
| 2026-08-30 | `TLSegmentedControlSize` 改成巢狀的 `TLSegmentedControl.Size` | 它是這個元件的支援型別不是獨立元件，卻是頂層 public（契約檢查 2 抓到）。`Option` 本來就是巢狀的，一致性上它也該是。所有呼叫端都靠型別推論寫 `size: .compact`，所以無痛 |
| 2026-08-30 | `compact` 的六個數值改成 token | 元件內部的字面值也是字面值 |
| 2026-08-30 | 記錄 `compact` 的來由 | `handoff-20` §B：軌道 4→2、段落 6/14→5/13、字級 12.5→12、移除選中陰影。原因是「重量單位那一列因為分段控制而明顯較高，且是全頁最亮的元素，視覺重量與重要性不符」 |
