# 交付說明 · 第六輪（階段 2 動作庫 ＋ 中文字級第一批）

> 給設計端。每輪重寫，只講「這輪跟上輪的差別」與「這輪想請你看什麼」。
> 規則書是 `README.md`（正典），完整決策脈絡在 `CHANGELOG.md`。
> 日期：2026-08-31

---

## 這一包有什麼

| | |
|---|---|
| Atoms 10 | TLBadge · TLCheckCircle · TLChevron · TLCircleIconButton · TLDivider · TLIconThumbnail · **TLProgressBar** · TLRowValue · TLSettingsValue · TLToggle |
| Molecules 12 | TLBackBar · TLDividedVStack · TLEquipmentTag · TLGroup · **TLInlineEmptyState** · TLListRow · TLPageHeader · **TLRowContent** · TLSectionHeader · TLSegmentedControl · TLSettingsRow · TLSettingsToggleRow · **TLTitleWithTag** |
| **Organisms 4（新的一層）** | **ExerciseRow · TemplateRow · RotationRow · ProgramRow** |
| Examples 2 | 設定選擇頁 · 級距設定頁 |
| 機器檢查 | **17 條**（新增字級尺度的最小間距） |

元件 19 → **27**。粗體是這一輪新增或改名的。

---

## 一 · 階段 2 的核心問題有答案了

上一輪說階段 2 是**架構的賭注**：動作庫的 L3 全是列型，如果它們都能純由 L2 組成，
分層成立；有一個不行，就代表分子層設計錯了。

**答案：分層是對的，錯的是其中一個分子的介面。**

| L3 | 結果 |
|---|---|
| `ExerciseRow` | ✅ 純由 L2 組成，零缺口 |
| `RotationRow` | ✅ 純組合，兩種形態只是換填法 |
| `TemplateRow` | ⚠ `TLBadge(count:)` 顏色寫死，需要 neutral 圓章的呼叫端只能繞過它手工建 |
| `ProgramRow` | ❌ **用不了 `TLListRow`** |

### 那個「用不了」是這一輪最重要的發現

長期課表的「進行中」卡，原本**手工重建了整個 `TLListRow`**（圓章＋主副標＋chevron）。
查清楚不是偷懶，是真的用不了：

`TLListRow` 把兩件事放在同一個型別 —— **內容排版**與**列的外框**
（左右內距、最小高度、整列包成 Button）。那張卡有自己的內距、只有上半可點，
**外框全部不適用**，所以只能重畫一份，然後就漂了。

拆成 `TLRowContent`（只有排版）＋ `TLListRow`（＝ `TLRowContent` ＋ 外框）之後，
兩個呼叫端的手工重建都消失。

**這跟整輪重構的原則是同一條：把綁在一起的兩件事分開。**

---

## 二 · 你的第一批拍板已經落地

17 個字面值 → **13 個角色，52 處遷移**。你立的判準（「未來會不會分開走」而不是「差幾 px」）
記進 `CHANGELOG.md` 了。

```
34 pageTitle · 30 sheetTitle · 26 detailTitle · 21 cardTitle · 16 emptyTitle
15 rowTitle · 15 buttonLabel · 14 rowValue · 13 buttonLabelSmall(paired)
12.5 caption · 12 badgeText · 12 segCompact · 11.5 rowSub · 10.5 kicker
```

剩 7 處字面值，全是你指定留的：單位 4 處、膠囊裡的文字 1 處（都等第二批）、
`10` 與 `9.5` 2 處（低於可讀下限，等你排設計改動）。

---

## 三 · 三個檢查漏洞，都是這一輪被真東西抓出來的

### 1 · `TLFont.zh(15.5)` 從來沒被 ratchet 算過

ratchet 只認 `.font(.system(size: N))`。`TLFont.zh(15.5)` **長得像吃了 token**，
其實是字面字級 —— 59 處字級字面值一路躲過。

**所以我上一輪說「設定頁字面樣式 0」是錯的**：那一刻 `SettingsView` 裡就有一個 13。
基線重算 167 → 208。

### 2 · CSS 鏡像有兩個壞掉的 var，你這幾輪看到的圖示是錯的尺寸

```
components.preview.css   var(--icon-in-check-circle)   ← 正確是 --icon-inCheckCircle
components.preview.css   var(--icon-in-icon-button)    ← 正確是 --icon-inIconButton
```

**勾號與圓鈕裡的圖示一直是自動尺寸，不是 token 尺寸。**
根因：檢查 9 只掃 preview.html 不掃 CSS 檔，而且兩邊的比對都只認小寫，
偏偏 icon 的 token 是 camelCase —— 定義端與使用端**同時**被跳過，兩個錯誤互相掩護。
已改成大小寫都認，檢查 9 延伸到 CSS 檔。

### 3 · 交付給你的 `components.json` 少了三個欄位

規格從十二節收成八節時，生成器沒跟上（還在找 `## 10` 與 `## 11`）。
找不到就回空字串，於是 `composedOf`／`confusableWith`／`dontUseFor` **靜默變成空的**。

**你手上前幾包的 `components.json` 裡，每個元件都是 `composedOf: null`。**
「元件由什麼組成」是那份 JSON 最有用的欄位之一。已修好。

---

## 四 · 你的新規則一寫成檢查，就擋到你自己批准的表

你給的規則：「同一家族內兩個不同的值差距不得小於 1」。寫成檢查 17 之後立刻撞上：

```
rowSub 11.5 · badgeText 12 · segCompact 12 · caption 12.5
```

**四個角色擠在 1px 內。**

原因在我這邊：上一份使用清單把「已命名角色」與「還是字面值的」分成兩張表，
所以這件事沒有顯示出來。**清單的排版方式決定了你看不看得見問題。**

沒有靜默放行 —— 兩筆例外登記在 `tokens.json` 的 `_scaleExceptions`，
每跑一次檢查就印一次，未登記的違規是硬錯。要不要收，你決定。

---

## 五 · `rowIcon: 17` 查完了，結論跟你的兩個選項都不同

你說「要嘛是 paired 的一員、要嘛就該是 `icon.inline`(14)」。查下去發現前提不完整 ——
**`TLSettingsRow` 裡有兩個圖示尺寸不是一個**：

```
破壞性圖示（垃圾桶）  17  semibold  右間距 10
一般圖示              15  medium    右間距 13   ← 這個用的是 TLFont.rowTitle
```

那個 15 是**用字級 token 去量 SF Symbol**。全 app 只有這一處這樣做。
所以它跟 `rowIcon` 是同一類錯誤的兩個實例：圖示尺寸借住在字級體系裡。

而且 `inline`(14) 自己也不乾淨，四個使用處有一半不符合「跟文字並排」：

| 用處 | 旁邊是什麼 |
|---|---|
| `TLChevron` | 列尾的指示記號，不是跟文字並排 |
| `TLBadge` 裡的圖示 | **裝在 36pt 圓章裡** —— 照判準該是 `inXxx` 配對值 |
| `TLSearchField` | 配 15pt 輸入文字 |
| `TLSwipeToRevealRow` | 配 11.5pt 動作文字 |

**先搬不改值**：`type.rowIcon` → `icon.inRow`(17)，讓它不再躲在字級群組裡。
值怎麼收是設計判斷，見下面的問題三。

---

## 這輪想請你看的

**1 · 字級尺度小的那一端要不要收？**
`11.5 / 12 / 12 / 12.5` 四個角色在 1px 內。你的規則說不行，但那是你批准的表 ——
所以這題是「規則對還是表對」。

**2 · `detailTitle`(26) 與統計數字 `display 28` 差 2px**，兩種東西在爭同一張卡的最大字。
你說留第二批，這裡只是提醒它跟 display 尺度綁在一起。

**3 · 設定列的兩個圖示（破壞性 17 / 一般 15）要收成一個嗎？收在哪？**
另外 `TLBadge` 裡那個 14 是不是該變成 `icon.inBadge` 配對值？

**4 · L4 畫面層目前幾乎是空的。**
`screens.json` 列了 18 個畫面，`examples/` 只有 2 份（都是設定的子頁）。
五層模型裡 L4 沒有落點 —— 這是要補的，還是 L3 到畫面之間本來就不需要中間文件？
