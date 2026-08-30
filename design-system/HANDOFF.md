# 交付說明 · 第四輪（階段 1 · 設定頁榨取）

> 給設計端。每輪重寫，只講「這輪跟上輪的差別」與「這輪想請你看什麼」。
> 規則書是 `README.md`（正典），這份不是規則。
> 日期：2026-08-30

---

## 你要的那個答案

你在第三輪說：如果「設定頁完全由 L2 組成」不成立，你想看到的不是修好之後的結果，
而是**不成立的那個點**。

**答案：分層假設成立，但當時的元件庫不夠用。**

分層那半是對的 —— 設定頁的三個畫面**完全不需要任何 L3**。
但「由 L2 組成」在當時只是一個描述、不是事實：那些 L2 有一半不在元件庫裡
（兩個內聯在畫面裡、五個埋在大檔裡沒有地址、三個放錯層、分層目錄根本不存在）。

**撞到的兩個邊界都是「介面不夠」而不是「分層錯」**，完整記錄在 `CHANGELOG.md`：

1. **`TLListRow` 不知道自己被選中** —— 選取靠 `leading` 裡放什麼決定，
   所以無障礙的 selected trait 要呼叫端補，而呼叫端會忘。
   考慮過三種做法，**選了「維持現狀但記錄」**，因為加 prop 會動所有呼叫端、
   加新元件會多一個九成像的東西 —— 兩者都該在有更多樣本時決定。
   階段 2 有四個選取清單，那時才看得出哪個對。
2. **`TLSettingsToggleRow` 沒有 disabled** —— 通知授權被拒後開關仍顯示開著。
   這不是榨取能解決的，已有 UI 設計票在排。

對架構來說這是好消息：分子層的**邊界**畫對了，只是有些分子的**介面**還沒長全。

---

## 這輪交付什麼

**19 個元件**（上一輪 1 個）＋ **2 份 example**。

| | |
|---|---|
| Atoms 9 | TLBadge · TLCheckCircle · TLChevron · TLCircleIconButton · TLDivider · TLIconThumbnail · TLRowValue · TLSettingsValue · TLToggle |
| Molecules 10 | TLBackBar · TLDividedVStack · TLGroup · TLListRow · TLPageHeader · TLSectionHeader · TLSegmentedControl · TLSettingsRow · TLSettingsToggleRow · TLValuePicker |

**設定頁的三個畫面現在是純組合** —— Presentation 的字面樣式從 13 降到 **0**。

**你的三個拍板都套用了**（`28×28/r7`、返回列 `gapS`、能力值另開票），
兩組變體因此都不用做 —— 少一份要維護的差異。

**兩個 example** 是你提的：`settings-selection` 目前是**零本地樣式**的純組合。

---

## 寫規格逼出來的東西

規格第 5 節要求「全部寫 token 名，不寫數字」，於是**元件內部自己的字面值**全部現形。
新增 25 個 token，其中三個值得你看：

- **`type.rowValue` 14** —— 字級尺度原本缺這一階（`rowSub` 11.5 與 `rowTitle` 15 之間空著）
- **`textBody`（→ neutral.700）** —— 這個色被用 16 處卻沒有語意角色。
  ⚠ **它與 `textSecondary`(neutral600) 的分界不清楚，需要你釐清** ——
  尤其考慮到 `textSecondary` 對容器底只有 3.9:1，`textBody` 反而更讀得到
- **`motion` 的落單值收斂了** —— 全專案唯一的 `0.18`（開關動畫）併進 `base`(0.2)

**`icon` 仍然不是一個尺度**：`s13 / sm14 / m16 / button18 / l20` 五個值都是從既有程式碼
撈出來的特設值，彼此沒有比例關係。這個要收斂需要你決定，記在已知缺口。

---

## 這輪想請你看的

**1 · 19 份規格的第 4 節（狀態），有沒有你需要但我漏掉的狀態？**
這是規格裡最容易漏的一節。我對每個元件都逐項回答了不適用的理由，
但「不適用」有時候是「我沒想到」的偽裝。

**2 · 第 10 節的「易混淆」對照，有沒有配錯或漏配？**
目前配了六組：`TLSettingsValue`↔`TLRowValue`、`TLChevron`↔`TLCheckCircle`、
`TLBadge`↔`TLIconThumbnail`、`TLSettingsRow`↔`TLListRow`、
`TLPageHeader`↔`TLBackBar`／`TLSectionHeader`、`TLValuePicker`↔`TLNumberField`。

**3 · `textBody` vs `textSecondary` 的分界**（見上）。

**4 · 三個記在規格裡的無障礙缺口，優先度怎麼排？**
`TLValuePicker` 的滾輪沒有 `adjustable` trait（最嚴重，VoiceOver 使用者無法調整）、
`TLListRow` 的 selected trait、`TLSettingsToggleRow` 的 disabled。

---

## 接下來：階段 2 · 動作庫

那是**整個架構的賭注** —— 7 個 L3 有機體全是列型，如果它們都能純由 L2 組成，
架構成立；有一個不行就代表分子層設計錯了，要在那裡修正而不是拖到訓練頁。

階段 1 已經先告訴我們一件事：分子層的**邊界**是對的。階段 2 要驗的是**介面夠不夠**。
