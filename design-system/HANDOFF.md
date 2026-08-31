# 交付說明 · 第七輪（TLCard 全面遷移 ＋ 階段 3、4）

> 給設計端。每輪重寫，只講「這輪跟上輪的差別」與「這輪想請你看什麼」。
> 規則書是 `README.md`（正典），完整決策脈絡在 `CHANGELOG.md`。
> 日期：2026-08-31

---

## 這一包有什麼

| | |
|---|---|
| Atoms 11 | TLBadge · TLCheckCircle · TLChevron · **TLCircleIcon** · TLCircleIconButton · TLDivider · TLIconThumbnail · TLProgressBar · TLRowValue · TLSettingsValue · TLToggle |
| Molecules 14 | TLBackBar · **TLCard** · TLDividedVStack · TLEquipmentTag · TLGroup · TLInlineEmptyState · TLListRow · TLPageHeader · TLRowContent · TLSectionHeader · TLSegmentedControl · TLSettingsRow · TLSettingsToggleRow · TLTitleWithTag |
| Organisms 7 | ExerciseRow · **PlanWorkoutRow** · ProgramRow · **ProjectedWorkoutRow** · RotationRow · TemplateRow · **WorkoutHistoryRow** |
| Examples 2 | 設定選擇頁 · 級距設定頁 |
| 機器檢查 | 17 條 |

元件 27 → **32**。Presentation 的字面樣式 208 → **128**。

---

## 一 · 我寫錯了一條規則，被 26 處實測推翻

上一輪抽 `TLCard` 時，我在規格裡寫了「**不要卡中卡**」。

全面遷移時發現 app 裡有 **9 處卡中卡**，而且它們**早就在用小一階的圓角**（20 而不是 28）。

**實際的規則不是「不要巢狀」，是「巢狀要換小圓角」。** 我那條禁令是只看了 17 處外層卡
就下的結論 —— 量到 26 處才看見全貌。

`TLCard` 因此多一個維度：

```
container 28   外層卡：直接坐在頁面底上的         15 處
inner     20   卡中的區塊：坐在另一張卡或群組裡的    9 處
```

這條規則現在是**元件強制**的，不是靠人記得。

---

## 二 · 三個同型的介面缺口，都是這一輪撞出來的

| 元件 | 缺什麼 | 呼叫端做了什麼 |
|---|---|---|
| `TLBadge(count:)` | 顏色寫死 sage | 需要 neutral 的自己手工建一份 |
| `TLSectionHeader` | 右側只收按鈕，不收唯讀文字 | 自己重畫一次 kicker |
| `TLGroup` | 不收描邊 | 自己疊一個 `strokeBorder` overlay |

**同一句話：介面少開一個口，呼叫端就會繞過整個元件、複製一份。**
三個都補好了。

---

## 三 · 第二個「視覺與互動綁在一起」的錯誤

上一輪是 `TLListRow` 把**內容排版**與**列的外框**綁死，卡片式版面用不了它。

這一輪是 `TLCircleIconButton` 把**圓形圖示的視覺**與 `Button` 綁死 ——
課表頁的 `+` 是 **`Menu` 的 label 不是 Button**，用不了它，只好手工重畫一份圓。
（訓練中的「更多」也有一份，那個更冤：它本來就是 Button，只是沒人知道有元件。）

拆出 L1 `TLCircleIcon`（純視覺）之後，`TLCircleIconButton` ＝ `Button` ＋ 它。

**兩次是同一個病**：把「長什麼樣」跟「按下去做什麼」放進同一個型別，
於是任何「要這個樣子但不是按鈕」的場合都只能複製。

---

## 四 · 兩個新階段

**階段 3（歷史）**：`TLCard` 就是在這裡量出來的（17 處，後來變 26）。
抽出 `WorkoutHistoryRow`，左件是日期柱（日數＋星期、固定寬 40）。

**階段 4（課表）**：`PlanWorkoutRow`（已排定）與 `ProjectedWorkoutRow`（投影未落地）。
**兩個都是純組合、零缺口** —— 分子層在這一頁完全夠用。

---

## 五 · 這一輪有三處視覺位移（使用者拍板，不是漂移）

| 位置 | 現值 | 併成 | 位移 |
|---|---|---|---|
| 休息日回顧卡 | 26/22 | 26/26 | +4px |
| 範本編輯的值方塊 | 18/12 | 18/18 | +6px |
| 訓練中的組表列 | 18/14 或 11 | 18/18 | +4／+7px |

⚠ 第三項請你看一眼：`current` 那一列原本比其他列**高 3px**，那是第三個狀態訊號
（另兩個是深底與未做列的淡出）。併掉之後只剩顏色，而且整張組表每列都變高。

---

## 這輪想請你看的

**1 · 卡底有三階，只有一階有語意名字。**

```
neutral-100 ＝ surfaceRaised      淺卡    9 處
neutral-300 （沒有名字）           深卡    5 處
accent-200  （沒有名字）           強調卡  2 處
```

`neutral-300` 在語意層叫 `surfaceInput`（輸入色帶），拿它當卡底是**借用**。
要命名嗎？還是這三階本身該收斂？

**2 · 訓練中組表列的高度**（見上面第五節）—— 那 3px 的狀態訊號要不要救回來？

**3 · 「列首固定欄」有三種寬度**：`40`（歷史的日期柱）、`44`（訓練詳情的組序）、
`48`（範本編輯的組序）。**後兩者是同一個角色的兩個值。** 跟膠囊幾何同型。

**4 · 字級小的那一端還沒收**（上一輪的問題，這輪沒動）：
`11.5 / 12 / 12 / 12.5` 四個角色在 1px 內，你的規則說不行。

**5 · L4 畫面層還是空的**（上一輪的問題）：`screens.json` 18 個畫面、`examples/` 只有 2 份。
