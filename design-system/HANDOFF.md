# 交付說明 · 第五輪（階段 1 ＋ 兩輪審閱回應）

> 給設計端。每輪重寫，只講「這輪跟上輪的差別」與「這輪想請你看什麼」。
> 規則書是 `README.md`（正典），完整決策脈絡在 `CHANGELOG.md`。
> 日期：2026-08-30

---

## 先講一件事：上一包你可能沒拿到最新的

你在階段 1 審閱裡說「`textBody` 併入 `textSecondary`」與「`.kicker` 對比度不足」
**兩件都沒動** —— 那兩件其實已經做了，只是你手上那包比較舊。

**這一包裡兩件都在。** 完整的文字階見下面第 2 節。

---

## 你抓到一個真的錯誤

`--icon-m` 的矛盾成立，**而且錯的是我這邊的 CSS 鏡像**：

```
Swift  TLBadge 圖示建構子 → TLFont.rowTitle (15)
CSS    .tl-badge svg      → var(--icon-m)  (16)
```

`--icon-m` 全專案唯一的使用者就是那一行錯的 CSS。已修正（現在對到 `icon.inline`）。

**這正好是檢查 16 擋不到的那種漂移。** 它擋孤兒與遺漏，但**兩份實作的值不一致擋不了**
（那要跨語言比對）。契約裡寫過這個限制，這次它真的發生了，
而且是被人眼交叉比對抓到的 —— 已記進 `CHANGELOG.md` 當作那條限制的實例。

---

## 這一包跟你上次看到的差在哪

### 1 · `preview.css` 分家（你的審閱 A）

你指出 `preview.css` 已經從「展示骨架」變成**元件的第二份實作** ——
`.thumb` 帶著 `linear-gradient` 與 `--size-icon-thumb`，那是元件的樣子不是骨架。

照你的建議做成**顯性化並可計數**，沒有退回去：

- `preview.css` 只留骨架（110 行）
- 元件鏡像進 **`components.preview.css`**（200 行），一元件一段、順序同 `components.json`
- 選擇器一律 **`.tl-<kebab-name>`**。原本的 `.btn`／`.check`／`.thumb` 是通用名，
  等 `TLButton`／`TLTag` 進來一定撞
- 規格第 1 節多一列 **`Preview CSS`** —— 三件套變四件套，因為事實上已經是了
- **新增檢查 16**：孤兒段落、重複段落、preview 用了未定義的 `.tl-`，三種都反向測過

加上檢查後**立刻抓到一個真孤兒**：`.tl-over` 是 `TLBadge` preview 特有的溢出示意，
不該有 `tl-` 前綴，已改成本地 class。

### 2 · 文字階合併下移（你的審閱 B）

| token | 原本 | 現在 | 對 `surfaceRaised` |
|---|---|---|---|
| `textPrimary` | ink.900 | ink.900 | 15.2:1 |
| `textSecondary` | neutral.600 | **neutral.700** | **6.0:1**（原 3.9） |
| `textTertiary` | neutral.500 | **neutral.600** | **3.9:1**（原 2.6） |
| ~~`textBody`~~ | neutral.700 | 刪除 | 併入 `textSecondary` |

你給的判準記進 `CHANGELOG.md` 了：
> 要讀完的**句子**用 `textSecondary`，掃視就過的**標示**用 `textTertiary`。
> 不是「重要程度」，是「會不會被逐字讀」。

`.kicker` 也照你說的改成 `textSecondary`（10.5px 小字配低對比讀不動）。

**視覺影響現在很小**：Swift 端還在直接用 `neutral500`(91 處)／`neutral600`(64 處)，
只有 2 處走語意層。這是改**定義**，效果會在後續階段遷移時逐步落地。
`TLChevron` 是唯一立刻變的（2.6 → 3.9，變深，是修正）。

### 3 · icon 尺度收斂（你的四項拍板）

五個特設值 → **兩組四個**：

```
inline 14         standalone 22        ← 真的尺度刻度
inCheckCircle 11  inIconButton 18      ← 裝在固定容器裡的配對值
```

- `icon.l`(20) 刪除
- `13`／`14`／`15` 收成 **14**，改名 `icon.inline`
- 容器內圖示用固定配對值、不用比例；`TLCircleIconButton.iconSize` **不開成 prop**
- `22` 兩處先共用 `icon.standalone`

命名刻意用 `inXxx` —— **那些不是刻度**，拿去跟 `inline`／`standalone` 比較沒有意義。

`_note` 加了你建議的防再犯判準：
> 新增圖示尺寸前先問：它是跟文字並排、獨立擺放、還是裝在某個容器裡？
> 前兩者用既有的兩階；第三者才新增一個 `inXxx` 配對值。

順帶把四個尚未榨取的元件的字面 SF Symbol 字級一起收進來
（`TLEmptyState` 22、`TLTabBar` 22、`TLSearchField` 15×2、`TLSwipeToRevealRow` 15）。

### 你的三則建議

| 建議 | 處理 |
|---|---|
| paired 那組加 `_note` 防再犯 | 做了（見上） |
| 空狀態日後放大要開新階、別動 `standalone` | 記進已知缺口，並註明現在的 22 是「先共用」不是「確認同性質」 |
| 那個 `1×12` 的零星值在哪 | `AbilityListView.swift:349`。**是文字不是圖示**，但沒有對應的字級角色。記進已知缺口，留給撞到 Ability 的階段 |

---

## 階段 1 的核心答案（如果你還沒看到）

你在第三輪要求：如果「設定頁完全由 L2 組成」不成立，你想看到**不成立的那個點**。

**答案：分層假設成立，但當時的元件庫不夠用。**

設定頁三個畫面**完全不需要任何 L3**。但「由 L2 組成」在當時只是描述、不是事實：
那些 L2 有一半不在元件庫裡（兩個內聯在畫面、五個埋在大檔沒有地址、三個放錯層、
`Atoms/`／`Molecules/` 目錄根本不存在）。

**撞到的兩個邊界都是「介面不夠」而不是「分層錯」**：

1. **`TLListRow` 不知道自己被選中** —— 選取靠 `leading` 放什麼決定，
   無障礙的 selected trait 要呼叫端補而呼叫端會忘。
   考慮過加 `isSelected` prop／加 `TLSelectableRow`／維持現狀三種，
   **選了維持現狀但記錄** —— 前者動所有呼叫端、後者多一個九成像的元件，
   都該在有更多樣本時決定。階段 2 有四個選取清單。
2. **`TLSettingsToggleRow` 沒有 disabled** —— 通知授權被拒後開關仍顯示開著。
   不是榨取能解決的，已有 UI 設計票在排。

對架構是好消息：分子層的**邊界**畫對了，只是有些分子的**介面**還沒長全。

---

## 這一包有什麼

| | |
|---|---|
| Atoms 9 | TLBadge · TLCheckCircle · TLChevron · TLCircleIconButton · TLDivider · TLIconThumbnail · TLRowValue · TLSettingsValue · TLToggle |
| Molecules 10 | TLBackBar · TLDividedVStack · TLGroup · TLListRow · TLPageHeader · TLSectionHeader · TLSegmentedControl · TLSettingsRow · TLSettingsToggleRow · TLValuePicker |
| Examples 2 | 設定選擇頁 · 級距設定頁（皆為沒有設計稿的子頁，**這兩份 example 就是它們的規格**） |
| 機器檢查 | 16 條，每條都反向測過會擋 |

設定頁三個畫面的 Presentation **字面樣式為 0**。

---

## 這輪想請你看的

**1 · `components.preview.css` 的分段粒度對嗎？**
現在是一元件一段。`TLGroup`／`TLDivider`／`TLDividedVStack` 刻意沒有段落 ——
它們的視覺表述**就是**骨架的 `.group`／`.row`，因為那三個元件「是」容器與分隔線本身。
這個例外合理嗎？

**2 · 19 份規格的第 4 節（狀態），有沒有你需要但我漏掉的？**
我對每個元件都逐項回答了不適用的理由，但「不適用」有時候是「我沒想到」的偽裝。

**3 · 第 10 節的「易混淆」對照有沒有配錯或漏配？**
目前六組：`TLSettingsValue`↔`TLRowValue`、`TLChevron`↔`TLCheckCircle`、
`TLBadge`↔`TLIconThumbnail`、`TLSettingsRow`↔`TLListRow`、
`TLPageHeader`↔`TLBackBar`／`TLSectionHeader`、`TLValuePicker`↔`TLNumberField`。

**4 · 三個無障礙缺口的優先度怎麼排？**
`TLValuePicker` 的滾輪沒有 `adjustable` trait（最嚴重，VoiceOver 使用者無法調整）、
`TLListRow` 的 selected trait、`TLSettingsToggleRow` 的 disabled。

---

## 接下來：階段 2 · 動作庫

那是**整個架構的賭注** —— 7 個 L3 有機體全是列型，如果它們都能純由 L2 組成，
架構成立；有一個不行就代表分子層設計錯了，要在那裡修正而不是拖到訓練頁。

階段 1 已經告訴我們分子層的**邊界**是對的。階段 2 要驗的是**介面夠不夠**。
