# 元件庫變更紀錄

元件自身的改動記在各自 spec 的第 12 節。**token 與契約層級的改動記這裡** ——
那些改動不屬於任何單一元件，但會影響每一個元件，之前沒有地方可以記。

刪一個 token 是設計決策，不是清理。所以刪除也要記，而且要寫清楚是哪一種情況：
角色不需要了／只是改名／被別的 token 吸收。

---

## 2026-08-30 · 第二輪設計端審閱後

### token

- **刪除語意 token `surfaceSunken`**（原本指向 `sand.raised` `#EBDDC5`，職責「頁面上的表面色塊」）。
  **屬於「角色不需要了」**：查證 `TLColor.surface` 全專案 **0 處使用**，
  它是 0a 建立語意層時，我幫一個從未被用過的色票發明的角色 —— 為沒有用途的顏色發明語意名，
  正是取錯名字的來源。舊名 alias `surface` 一併移除。
  **沒有任何畫面的顏色因此改變。**
  色階層的 `sand.raised` **保留**：它是原始色票的一員，只是目前沒有語意角色指向它。
  之後若有畫面需要「頁面上的表面色塊」，在那時依實際用途命名，不要現在預先發明。

- 新增 `icon`（`s`/`m`/`l`／`weight`／`strokeWeb`）與 `motion`（`fast`/`base`/`curve`）兩組。
  `motion` 的值取自程式碼現況（easeOut 0.2／0.18／0.15），不是憑空定的三階；
  `0.18` 是落單值，收斂前不要新增第四個值。

- 語意色改名：`accentOnLight` → `accentOnSurface`、`dangerOnLight` → `dangerOnSurface`。
  違反 §5「語意 token 名不得帶外觀」—— `OnLight` 預設了底色是淺的，深色接上時會直接說謊。

- `--icon-stroke` 的 `2.75` 原本是生成器裡的字面值，不是從 `tokens.json` 來的。
  補 `icon.strokeWeb` 當來源 —— 單一來源在這裡漏了一個洞。

### 契約

- §7.3 加上**展示骨架的豁免**：色票方塊、示意方塊的尺寸可以用字面值（「色票要畫多大」跟設計系統無關），
  但**字面色值永遠不豁免**。不寫的話，第一次跑 lint 就會有人為了過檢查把 `46px` 塞成 token，汙染 token 表。
- §8 的檢查表改成**從 `check-design-system.py` 的 `CHECKS` 生成**。
  `scripts/` 不進交付包，README 是設計端唯一看得到「實際擋了什麼」的地方；
  手寫一定會過期，然後審閱會針對一份虛構的清單提意見（第二輪就發生了兩次）。

### preview

- 共用外殼 `preview.css` 的**列間分隔線原本橫跨整列寬，是錯的**。
  app 的 `TLDivider` 有 `.padding(.leading, TLSpace.rowInset)`，分隔線左內縮 18。
  改用 `::after` 定位。錯在共用外殼裡，所有元件會一起錯。

### 新增檢查

- **10** preview 用到的字都要在子集字型裡。內嵌中文子集換來 preview 自足，
  代價是「改了文案沒重生子集就靜默缺字」。
- **12** 文件裡提到的 token 名都要真的存在。抓「token 被刪／改名，文件還在講它」。

---

## 2026-08-31 · 階段 3（歷史）· 找到全 app 最大的一筆重複

### `TLCard` 缺席 —— 17 處手工重建，跨 6 個 package

下行拆解時量的，不是猜的：

```
padding(rowInset) ＋ background(...) ＋ clipShape(RoundedRectangle(container))
```

| 底色 | 處數 | 例子 |
|---|---|---|
| `neutral-100`（＝ `surfaceRaised`） | 9 | 趨勢圖卡、能力值卡、動作表單卡、長期「進行中」卡 |
| `neutral-300`（**沒有語意名字**） | 5 | 達成摘要、長期詳情、循環詳情、完成摘要 |
| `accent-200`（**沒有語意名字**） | 2 | 訓練中的當前組、能力值的當前值 |
| 只有描邊 | 1 | 循環清單的進行中框 |

**比 `TLInlineEmptyState`（4 處）大四倍**，是目前為止最大的一筆。

底色做成 **prop 而不是 enum**：三階裡有兩階還沒有語意名字，做成 `enum` 等於
現在就替設計端命名 —— 那不是我的決定。`neutral-300` 在語意層叫 `surfaceInput`
（輸入色帶），拿它當卡底是**借用**。命名已列進待問清單。

### `TLSectionHeader` 的右側只開放給按鈕

歷史的月份區塊要「共 N 小時」這種**唯讀文字**，但那個元件的右側只收 `actionLabel`＋`action`。
於是 `HistoryView` 自己重畫了一次 kicker（字級、字距、顏色、下方間距全部重寫一遍）。

**跟 `TLBadge(count:)` 顏色寫死是同一型：介面少開一個口，呼叫端就會繞過整個元件。**
補上 `trailing: Text?` 之後那段手寫消失。

### 抽出 `WorkoutHistoryRow`（L3）

歷史清單的一列。左件是**日期柱**：日數 ＋ 星期兩行堆疊、固定寬 40。
固定寬是為了讓整個月的日期左緣對齊 —— 跟著內容走的話 10 號與 9 號會差一個字寬。

⚠ 順帶量到：**「列首固定欄」有三種寬度** —— `40`（日期柱）、`44`（逐組列的組序）、
`48`（範本編輯的組序）。**後兩者是同一個角色的兩個值**，跟膠囊幾何同型。已列進待問清單。

### 進度

History 38 → 15。剩下的全部有記錄：display 尺度 8、單位字級 3、膠囊幾何 4。
基線 163 → 140。

新 token：`space.statGap` 28 · `space.cardSectionGap` 16 · `space.dateStackGap` 1 ·
`size.chart` 200 · `size.legendDot` 8 · `size.dateColumn` 40 · `size.setIndexColumn` 44。

---

## 2026-08-31 · 動作庫的字面樣式清到剩「有理由的 17 處」

45 處遷移。**`Spec` 歸零**，`Plan` 71 → 29（其中 12 處屬於課表分頁，不是這一階段的）。

### 新 token 6 個

| token | 值 | 用在哪 |
|---|---|---|
| `size.gridCell` · `radius.gridCell` · `space.gridGap` | 18 · 5 · 4 | 長期課表編輯頁的格狀預覽。格子小，圓角要跟著小（比 `iconThumb` 7 更方） |
| `size.rowLeadColumn` | 48 | 列首的固定欄（序號）。**與既有的 `rowTailColumn` 80 對稱** |
| `space.fieldPadV` | 12 | 可點的值方塊（重量／次數）上下內距 |
| `space.sheetBarTop` | 14 | 整頁 sheet 頂端關閉列的上緣。不是 `TLCompactSheet`（那個用 `gapL`） |

### 兩處刻意的 −1px

`ProgramListView` 的提示卡標題／說明間距 `3` → `space.titleSubGap`(2)。
理由與字級同一條：**同一個關係只該有一個值**，3 與 2 表達的是同一件事（標題與其下的說明）。

`ProgramListView` 的燒瓶圖示 `13` → `icon.inline`(14)，+1px。同理。

### 剩下的 17 處，每一處都有記錄

| 剩下 | 數量 | 為什麼 |
|---|---|---|
| `TLFont.display(N)` | 8 | 第二批（display 尺度） |
| 膠囊幾何（`7/14`、`10/5`、`10/滿寬`） | 5 | 第二批（膠囊三分法） |
| 詳情頁自寫返回列的 `.padding(.top, 12)` | 2 | 已知缺口：改用 `TLBackBar` 之後會變成 8，那是階段 4 的視覺改動 |

**不是「清不完」，是「清到剩下的都在等別人拍板」。**

---

## 2026-08-31 · 中文字級收斂（設計端第一批拍板）＋ 三個檢查漏洞

### 17 個字面值 → 13 個角色，52 處遷移

設計端立了一條判準，它決定了四題裡的三題：

> **併不併看「未來會不會分開走」，不是「現在差幾 px」。**
> 兩個角色同值、但各自有獨立的未來 → 兩個 token，值可以一樣。
> **同值的兩個 token 不會製造漂移，字面值才會。**

這也解釋了為什麼結論跟上一輪的 `textBody` 不同：`textBody` 與 `textSecondary`
是同一件事的兩個名字，按鈕與列標題不是。

| 角色 | 值 | 來源 |
|---|---|---|
| `sheetTitle` | 30 | 新。sheet 的大標比 page 小一階是刻意的——sheet 是次級表面 |
| `buttonLabel` | 15 | 新。取代 15 處的 `15.5`（−0.5px）。與 `rowTitle` 同值但各有各的未來：按鈕受 44pt 觸控區約束、列標題受 56pt 列高約束 |
| `buttonLabelSmall` | 13 | 新。`buttonLabel` 的**配對值**，照 icon `inXxx` 的模式，不算尺度階 |
| `caption` | 12.5 | 原 `emptyHint`。名字綁死在空狀態會讓人不敢拿它放編輯頁說明文字，然後又寫一個 13 |
| `cardTitle` | 21 | 併入 `20`（對話框、區塊標題）與 `19`（月曆標題） |
| `detailTitle` | 26 | 新。歷史詳情那個 `26` **不是漂移，是頁標題住在卡裡** |

`0.5px` 沒有立場留下：尺寸差 0.5 在螢幕上不存在，「按鈕要比列標題重一點」該由**字重**做。

### `26` 那一題：先查位置，結論才翻過來

設計端的反問是「歷史詳情是 sheet 還是頁」，兩條路都是併掉。**但兩條路都不對** ——
查到的位置是 `WorkoutDetailView.swift:132`，那不是頁標題也不是 sheet 標題：

```
歷史詳情頁
├ 導覽列          系統畫的 inline 日期        ← 頁面沒有 pageTitle(34)
├ kicker         10.5
└ 達成摘要卡
   ├ 訓練名稱     26  ← 問題中的值。整頁最大的中文字
   ├ 副行／備註   rowSub 11.5
   └ 統計數字     display 28                 ← 卡裡沒有 cardTitle 可作對照
```

所以它是**頁標題住在卡裡**：導覽列只承載日期，真正的標題在內容區第一張卡。
設計端據此改判 —— 保留 26 並命名 `detailTitle`，理由是它**描述得出一個職責**
（任何「導覽列不承載標題」的詳情頁都是它），這也是它跟 `icon.l`(20) 的差別：
那個是找不到職責的剩餘值。**一處使用撐不起一個階，一個說得出來的職責撐得起。**

若照原本的兩條路併進 `cardTitle`(21)，那一頁最大的中文字會比它下面的統計數字小 7px ——
現在層級沒有反，併了才反。

**教訓與 icon 那次同型**：我上一份清單只寫了畫面名（「26 → 歷史詳情」），
沒寫它在畫面裡的**哪個位置**，所以對方只能猜它是標題，兩個選項都建立在錯的前提上。
使用清單要給位置，不是給畫面。

### `rowIcon: 17` 根本不是字級

它住在 `type.roles` 裡，但它是 `TLSettingsRow` 左側 SF Symbol 的點數。
**因為住在字級群組，它躲過了上一輪的 icon 收斂**（那次把五個特設值收成兩組四個）。

已搬到 `icon.inRow`（值不變）。⚠ 若嚴格照設計端自己的判準「跟文字並排 → `icon.inline`」，
它該是 14 —— 那是 −3px、動到每一列設定的視覺改動，留給設計端拍板。

### 檢查 7 有個大洞：`TLFont.zh(15.5)` 從來沒被算過

ratchet 只認 `.font(.system(size: N))` 與 `.font(.custom(…, size: N))`。
`TLFont.zh(15.5)` 長得像吃了 token，其實是**字面字級** —— 於是 59 處字面字級
一路躲過了 ratchet。

**「設定頁字面樣式 0」被宣告的那一刻，`SettingsView` 裡就有一個 13。**
那句話是錯的，錯在量的東西漏了一整類。

已補進 `LITERAL_STYLE`，基線跟著重設：167 → **209**（多出來的 42 就是原本看不見的字級字面值，
其中 36 個是 display 家族，等第二批）。

### 檢查 9 也有洞：CSS 檔裡打錯的 var 名字沒人管

檢查 9 只掃 `preview.html`，不掃 CSS 檔本身。而 CSS 裡 `var(--icon-in-check-circle)`
打錯名字是**靜默失效**（渲染成無效值）。

實際抓到兩個壞掉的：

```
components.preview.css   var(--icon-in-check-circle)   ← 正確是 --icon-inCheckCircle
components.preview.css   var(--icon-in-icon-button)    ← 正確是 --icon-inIconButton
```

**設計端這幾輪看到的勾號與圓鈕圖示一直是自動尺寸，不是 token 尺寸。**
根因是兩邊的比對規則都只認小寫，而 icon 的 token 是 camelCase（`--icon-inCheckCircle`）——
所以定義端與使用端**同時**被跳過，兩個錯誤互相掩護。已改成大小寫都認，並把檢查 9 延伸到 CSS 檔。

### 新增檢查 17：字級尺度的最小間距

設計端拍板的規則：

> 同一個家族內，兩個**不同**的值差距不得小於 1。同值的兩個角色是允許的。

**這條規則一寫出來就擋到設計端自己批准的表**：`rowSub` 11.5 / `badgeText`·`segCompact` 12 /
`caption` 12.5 —— 三個角色擠在 1px 內。

原因是我上一份使用清單把「已命名角色」與「還是字面值的」分成兩張表，
所以四個角色擠在一起這件事沒有顯示出來。**清單的排版方式決定了對方看不看得見問題。**

沒有靜默放行：兩筆例外登記在 `tokens.json` 的 `_scaleExceptions`，每跑一次檢查就印一次，
未登記的違規是硬錯。`paired` 的角色（`buttonLabelSmall`）不算尺度階。

### 不做 token 化的三處

`10`（週進度列）、`9.5`（歷史清單）——設計端判定**低於可讀下限**，
不併進 `kicker`(10.5)，要連同 kicker 的對比度一起檢視。三處都留著字面值，
已進已知缺口。這是設計改動不是收斂。

### 留給第二批

`26`（歷史詳情）、display 家族 13 個值 36 處、單位字級（`13`×3、`15`×1）、
膠囊幾何 11 種。單位跟著旁邊的 display 數字走，不由中文字級決定。

---

## 2026-08-31 · 階段 2 續：L3 規格補齊、生成器修好

### 交付給設計端的 `components.json` 少了三個欄位而沒有人報錯

規格從十二節收成八節時，`gen-design-index.py` 沒跟上：它還在找
`## 10 用法與禁用法` 與 `## 11 組成 ★`。兩個標題都不存在了，
`sect()` 找不到就回空字串 —— 於是 `composedOf`／`confusableWith`／`dontUseFor`
**靜默變成空的**。

設計端拿到的 `components.json` 裡，22 個元件全部 `composedOf: null`。
**「元件由什麼組成」是這份 JSON 最有價值的欄位之一，而它空了不知道幾輪。**

修好之後：組成從第 1 節讀、易混淆的比對也認 L3（原本只抓 `TL\w+`，
`TemplateRow` 這種不以 TL 開頭的名字整組漏掉）。

### 補上五份規格

| | |
|---|---|
| `TLRowContent`（L2） | **階段 2 最重要的那個修正**，之前只有程式碼沒有規格 |
| `TLTitleWithTag`（L2） | 從 `TLEquipmentTag.swift` 拆出、去掉名字裡的 domain 詞彙 |
| `TemplateRow`／`RotationRow`／`ProgramRow`（L3） | 只有 `ExerciseRow` 有規格，另外三個沒有 |
| `TLSwipeToRevealRow`（控制項） | L3 的組成宣告指得到它才有意義 |

檢查 11 現在也認 `_controls/` 的元件 —— 否則 L3 的組成只能寫得含糊，
而那正是這條檢查要擋的東西。檢查 16 的段落比對也認 L3（原本只認 `TL` 開頭）。

### 順手抓到的兩個實作／鏡像不一致

**副標的顏色**：`TLRowContent` 用 `neutral-500`，CSS 鏡像寫 `text-secondary`(neutral-700)。
文字階合併後 Swift 端還有九十幾處沒遷移。**鏡像改成跟著實作走** ——
鏡像的用途是讓設計端看到 app 現在長什麼樣，不是長什麼樣才對。遷移列進已知缺口。

**進度條軌道的方向**：規格寫「軌道要比所在的底稍深」，但實際上長期課表詳情那張卡是
`neutral-300` 的深底，軌道傳的是**更淺**的 `neutral-100`。方向不是固定的 ——
那才是 `track` 不能寫死的真正理由。規格、元件註解、CSS 註解三處都改了。

順帶：`ProgramRow` 傳的 `neutral-200` 就是預設值 `surfaceTrack` 本身，拿掉了。

### token

`size.swipeAction` 88（左滑動作區寬，原本是控制項裡的字面值）。

---

## 2026-08-31 · 階段 2（動作庫）· 四個 L3 抽出，賭注有答案了

### 核心問題：7 個 L3 能不能純由 L2 組成？

**答案：能，但有兩個分子的介面把兩件事綁死了，要先拆開。**

跟階段 1 同型 —— 分子層的**邊界**是對的（沒有一個 L3 需要新的分子概念），
不夠的是某些分子的**介面**。

| L3 | 結果 |
|---|---|
| `ExerciseRow` | ✅ 純由 L2 組成，零缺口 |
| `TemplateRow` | ⚠️ `TLBadge(count:)` 顏色寫死 sage，需要 neutral 的呼叫端只能繞過它手工建 |
| `RotationRow` | ✅ 純組合 |
| `ProgramRow` | ❌ `TLListRow` 把排版與外框綁死，卡片式版面用不了 |

### 失敗點一：`TLListRow` 用不了（最重要的一個）

`ProgramListView` 的「進行中」卡**手工重建了整個 `TLListRow`**（圓章＋主副標＋chevron）。
查清楚原因不是偷懶，是**用不了**：

`TLListRow` 把兩件事放在同一個型別 ——
**內容排版**（`HStack` ＋ 主副標 ＋ trailing ＋ chevron）
與**列的外框**（`rowInset` padding、`minHeight`、整列包成 `Button`）。

那張卡有自己的 padding、只有上半可點、下半是進度條 —— **外框全部不適用**，
所以只能重畫一份，然後就漂了。

**解法：拆成 `TLRowContent`（只有排版）＋ `TLListRow`（＝ `TLRowContent` ＋ 外框）。**
兩個呼叫端改用 `TLRowContent` 之後，手工重建消失。

這跟整個重構的原則是同一條：**把綁在一起的兩件事分開**。

### 失敗點二：`TLBadge(count:)` 顏色寫死

同一個檔裡 `init(icon:fill:tint:)` 已經把顏色開成 prop，`init(count:)` 卻寫死 sage200/sage800。
所以需要 neutral 圓章的 `TemplateRow` 只能繞過便利建構子手工建一份。

**介面不一致本身就是缺口** —— 兩個 init 做同一類事，一個開放一個不開放。已補齊。

### 順帶收掉的三個重複

| | |
|---|---|
| `TLProgressBar`（L1） | 兩處各手工重建（`GeometryReader` ＋ 兩個 `Capsule`），只差軌道色。**設計文件的 L1 清單本來就有它，只是實作沒有** |
| `TLInlineEmptyState`（L2） | 四個清單頁各一份**一字不差**的實作 |
| `TLTitleWithTag` | 原名 `TLExerciseNameWithEquipment` —— 名字帶 domain 詞彙，階段 0c 就標記了。順便從 `TLEquipmentTag.swift` 拆出來（一檔兩元件） |

### 檢查器要認得 L3

L3 住在各自 package 的 `Presentation/Components/`，**不需要 `public`**（沒有跨 package 使用），
而且多半用 memberwise init。檢查 2／3 原本是為 L1／L2 寫的，會誤報。

放寬成：`organisms` 層允許非 public 的頂層型別；沒有顯式 init 時用 stored property 當 props
（`var body: some View` 是 computed，排除）。

### ⚠ 第三次撞到同型問題：膠囊幾何未收斂

專案裡有 **5 種膠囊形狀的東西，內距全不一樣**：

```
TLEquipmentTag  5/9      TLMuscleTag  5/12     進度膠囊  5/10
詳情頁膠囊       7/14     表單按鈕     10/滿寬
```

設計文件說 `TLTag` 是「capsule 5×12、11.5pt semibold、**6 種 style**」——
**意圖是一個標籤六種顏色，實作卻在幾何上各自漂了**。

這是繼 icon 尺度、字級尺度之後第三次撞到同型問題。統一是設計決策，
會跟字級尺度一起產使用清單問設計端，**不自己決定**。

### token

`size.progressBar` 6 · `size.rowTailColumn` 80 · `type.emptyTitle` 16 ·
`type.emptyHint` 12.5 · `type.cardNumber` 26 · `space.emptyStateGap` 8 ·
`space.emptyStatePadV` 40 · `space.numberUnitGap` 4 · `space.tagPadV` 5 · `space.tagPadH` 9

### 進度

元件 20 → 22（含第一個 L3）。動作庫字面樣式 66 → 53（Spec 5→3、Plan 61→50）。
剩下的集中在編輯頁（`ProgramEditorView` 11、`TemplateFormView` 8、`RotationDetailView` 8）。

---

## 2026-08-30 · 元件庫只留純呈現，控制項分出 DesignControls

### 起因：範圍檢討

問到「是否有過度考量的地方」，量了一下比例：

```
元件本體      981 行
周邊         5,879 行   ≈ 6 倍（規格 2073 · scripts 1248 · preview 1281 · 文件 967 · css 310）
進度         5 個階段做完 1 個
```

同時確認了兩件之前沒對齊的事：

1. **這個專案不做無障礙**（`ARCHITECTURE.md:221` 白紙黑字），但我在 19 份規格裡
   寫了 §9、把 VoiceOver 當要求、還排了「無障礙缺口」的優先度 —— 那整條線是我加的範圍
2. **元件庫不該包含邏輯**，純粹元件

### 判準

> **元件不得持有或改變自己的狀態**（`@State` / `@FocusState`），
> **不得計算**（格式化、日期、幾何）。
> `@Binding` 與 closure prop 是**資料通道**，可以留。

量出來的分佈很乾淨：19 個已抽的元件裡只有 3 個有真邏輯，其餘已經是純的。

### 分家

新增 **`DesignControls`** package，相依 `DesignControls → DesignSystem`（單向）。

| 留在 `DesignSystem`（純呈現） | 移到 `DesignControls`（有狀態或計算） |
|---|---|
| Atoms 9 · Molecules 9 · Components 7 · Support 2 | 12 個檔 |

移出的與原因：

| 元件 | 為什麼 |
|---|---|
| `TLWheelColumn` | 2 state · 4 gesture · **8 計算**（滾輪幾何） |
| `TLMonthDateStrip` | 3 gesture · **7 計算**（日期 ＋ 格線） |
| `TLNumberField` | state ＋ focus ＋ 字串↔數字轉換 |
| `TLValuePicker` `TLDualValuePicker` `TLRulerSlider` `TLIntensityFactorGroup` | 由滾輪組成，或自帶 state |
| `TLPickerSheet` | 2 state（搜尋、篩選） |
| `TLSwipeToRevealRow` `TLCompactSheet` `TLEditScaffold` | state ／ focus ／ gesture |
| `CalendarStripGeometry` | 純計算檔 |

**相依圖是封閉的** —— 這 12 個彼此互相引用，但沒有一個被留下的元件用到，所以能整批搬。
搬完 `DesignSystem` 與 `DesignControls` 都一次編過。

`WheelGeometry`（在 `TLWheelColumn` 檔內）與兩支幾何測試跟著搬。

**這是刻意選了嚴格版本。** 討論時提過兩條路：把「元件自己的排版數學」算成元件的一部分
（滾輪與月曆留下），或元件庫零計算（它們整批移出）。選後者 ——
代價是元件庫少掉幾個最常用的東西，好處是「元件庫裡沒有邏輯」變成一句沒有例外的話。

### 一個共用 helper 的處置

`OptionalIdentifier`（有值才套 `accessibilityIdentifier` 的 modifier）原本是
`TLConfirmationDialog.swift` 裡的 internal 型別，但搬走的 `TLPickerSheet` 也用它。
抽成 `Support/OptionalIdentifier.swift` 並開放。

它留在 `DesignSystem` 而不是刪掉，因為 **`accessibilityIdentifier` 是測試定位不是無障礙**。

### 無障礙移除

程式碼 23 處（`accessibilityLabel` 10、`accessibilityValue` 10、
`addTraits`／`Hidden`／`Element` 3）。**`accessibilityIdentifier` 22 處全部保留。**

兩個 prop 也拿掉：`TLBackBar.accessibilityLabel`（拿掉後它變成零 prop 的元件）、
`TLSettingsRow.accessibilityValue`（5 個呼叫端跟著改）。

先查證過 UITest 全部靠 identifier 定位，沒有一處靠 label。
`TLSettingsToggleRow` 那句「UITest 用 `switches["聲音"]` 查得到」的註解已經過時 ——
`check-i18n` 的規則 5 本來就擋中文字面值查找。

### 規格十二節 → 八節

砍 §9 無障礙；§7 文字行為與 §8 動態併進 §5（改名「度量與行為」）；
§11 組成併進 §1（那是「這個元件是什麼」的一部分）。

樣板加兩句判準：
- 「這個專案不做無障礙」寫在開頭
- §2 加「**元件不得有邏輯**」—— 看到 `format: (Double) -> String` 這種先問它為什麼在這裡

規格 2073 → 1890 行。**這次省得不多**（§7/§8 是合併不是刪除），
真正的省在後面 33 個元件，每個少寫四節。

---

## 2026-08-30 · icon 尺度收斂（設計端拍板）

### 一個真的錯誤：`--icon-m` 的矛盾

審閱交叉比對 `components.preview.css` 與使用清單，抓到一個**我的 CSS 鏡像畫錯了**：

```
Swift  TLBadge 圖示建構子 → TLFont.rowTitle (15)
CSS    .tl-badge svg      → var(--icon-m)  (16)
```

`--icon-m` 全專案唯一的使用者就是那一行錯的 CSS。

**這正是檢查 16 擋不到的那種漂移** —— 它擋孤兒與遺漏，但**兩份實作的值不一致擋不了**
（那要跨語言比對）。契約裡寫過這個限制，這次它真的發生了，而且是被人眼交叉比對抓到的。
記在這裡當作那條限制的實例。

### 拍板的四項

| | 決定 |
|---|---|
| `icon.l`(20) | 刪除（0 處引用） |
| `13`／`14`／`15` | 收成一個值 **14**，改名 **`icon.inline`**。±1px 位移可接受 |
| 容器內圖示 | 用**固定配對值**不用比例；`TLCircleIconButton.iconSize` **不開成 prop** |
| `22` 兩處 | 先共用 **`icon.standalone`** |

收斂後 `icon` 從五個特設值變成**兩組四個**：

```
inline 14      standalone 22       ← 真的尺度刻度
inCheckCircle 11  inIconButton 18  ← 裝在固定容器裡的配對值，跟著容器直徑走
```

命名刻意分成 `inXxx` —— **那些不是刻度**，拿它們去跟 `inline`／`standalone` 比較沒有意義。

`tokens.json` 的 `_note` 加了一條防再犯的判準（採納審閱建議）：
> 新增圖示尺寸前先問：它是跟文字並排、獨立擺放、還是裝在某個容器裡？
> 前兩者用既有的兩階；第三者才新增一個 `inXxx` 配對值。

順帶把四個尚未榨取的元件的字面 SF Symbol 字級一起收進來
（`TLEmptyState` 22、`TLTabBar` 22、`TLSearchField` 15×2、`TLSwipeToRevealRow` 15）。

### 生成器的一個修正

多行的 `_note` 生成出來的 Swift 註解只有第一行有 `//`，直接語法錯誤。
改成每一行都加 —— **token 的說明值得寫成多行，壓成一行會沒人讀**。

---

## 2026-08-30 · 階段 1 交付審閱後

### `preview.css` 分家（審閱 A）

審閱指出：`preview.css` 已經從「展示骨架」變成**元件的第二份實作** ——
`.thumb` 有 `linear-gradient` 與 `--size-icon-thumb`，那是元件的樣子不是骨架。
`TLBackBar` 因此有兩份實作（Swift 一份、CSS 一份）而**沒有東西檢查它們一致**。
19 個元件時看得住，40 個時會長成一份沒有規格、沒有狀態窮舉的平行設計系統。

**不退回去**（每份 preview 各自寫會更糟），改成**顯性化並可計數**：

- `preview.css` 只留骨架（`.group` `.row` `.kicker` `.pane` `.screen` `.note`）
- 元件的 CSS 鏡像進 **`components.preview.css`**，一元件一段、順序同 `components.json`
- 選擇器一律 `.tl-<kebab-name>`。原本的 `.btn` `.check` `.thumb` 是通用名，
  等 `TLButton`／`TLTag` 進來一定撞；靠 `.backbar .btn` 這種後代選擇器閃避撐不到 40 個元件
- 規格第 1 節多一列 `Preview CSS` —— **三件套變四件套，因為事實上已經是了**
- **新增檢查 16**：每個元件有且僅有一段對應的 `.tl-<name>`，反向也擋（孤兒段落）

一致性仍然沒人擋（那要跨語言比對，不值得做），但**孤兒與遺漏**擋得了 ——
而那是實際會發生的兩種漂移。加上檢查後立刻抓到一個孤兒（`.tl-over`，
那是 `TLBadge` preview 特有的溢出示意，不是元件的一部分，已改成本地 class）。

### 文字階合併與下移（審閱 B）

審閱：**兩個 token 同值就是一個 token。** `textBody` 與建議中的 `textSecondary`
都是 `neutral.700`，所以合併。同時整階下移一階：

| token | 原本 | 現在 | 對 `surfaceRaised` |
|---|---|---|---|
| `textPrimary` | ink.900 | ink.900 | 15.2:1 |
| `textSecondary` | neutral.600 | **neutral.700** | **6.0:1**（原 3.9） |
| `textTertiary` | neutral.500 | **neutral.600** | **3.9:1**（原 2.6） |
| ~~`textBody`~~ | neutral.700 | 刪除 | 併入 `textSecondary` |

**分界的判準**（審閱給的，值得記住）：
> 要讀完的**句子**用 `textSecondary`，掃視就過的**標示**用 `textTertiary`。
> 不是「重要程度」，是「會不會被逐字讀」。

`textTertiary` 的 3.9:1 過得了大字與圖示的 3:1、過不了正文的 4.5:1，
所以它的用途被限定成「圖示 ＋ ≥13pt 的非句子文字」。
順帶把 `preview.css` 的 `.kicker` 從 tertiary 改成 secondary —— 10.5px 的小字
配低對比會讀不動。

**視覺影響現在很小**：Swift 端還在直接用 `neutral500`(91 處)／`neutral600`(64 處)，
只有 2 處走語意層。所以這是改**定義**，效果會在後續階段逐步遷移時才落地 ——
`TLChevron` 是唯一立刻變的（2.6:1 → 3.9:1，變深，是修正）。

### icon 尺度（審閱 C）

清單產出在 `temp/icon-scale-usage.md`。**產清單時發現兩個值從來沒被用過**：

`icon.m`(16) 與 `icon.l`(20) 是第一輪建立 `icon` token 時憑空造的三階，
全專案 0 處引用。**這跟 `surfaceSunken` 是同一個錯誤** —— 為沒有用途的值發明名字。
已在清單裡建議刪除，等設計端確認。

清單同時指出一個可能的分法：跟文字並排的圖示（13/14/15，差異全在 ±1px 內）
與裝在固定容器裡的圖示（11 在 22pt 圓裡＝50%、18 在 44pt 圓裡＝41%）
**可能不是同一個尺度上的刻度**，後者是容器的比例。等設計端回覆。

---

## 2026-08-30 · 階段 1（設定頁榨取）· 完成

### 階段 1 的核心問題：「設定頁完全由 L2 組成」成立嗎？

設計文件 `11-component-inventory.md` 寫「Settings 無 L3，完全由 L2 組成 ——
**這是驗證元件庫是否夠用的最佳起點**」。這一階段就是去驗那句話。

**答案：分層假設成立，但當時的元件庫不夠用。**

分層那半是對的 —— 設定頁的三個畫面**完全不需要任何 L3**，
沒有一個地方需要認識 domain 型別。這是好消息，代表 L1/L2/L3 的分界是真的。

但「由 L2 組成」在當時**只是一個描述，不是事實**：那些 L2 有一半不在元件庫裡。

| 缺口 | 實際狀況 |
|---|---|
| **兩個元件內聯在畫面裡** | `TLIconThumbnail`（兩個畫面各寫一份，尺寸還不一樣）、`TLBackBar`（同上） |
| **五個元件沒有地址** | `TLBadge`／`TLCheckCircle`／`TLChevron`／`TLRowValue` 埋在 `TLListRow.swift`；`TLSettingsValue` 埋在 `TLSettingsRow.swift` |
| **三個元件放錯層** | `TLCircleIconButton` 與 8 個 `ButtonStyle` 同檔、`TLToggle` 在 `Components/`、`TLDivider` 與 `TLDividedVStack` 同檔 |
| **分層只存在於文件裡** | 程式碼沒有 `Atoms/`／`Molecules/` 目錄，L1 與 L2 混在同一個 `Components/` |

**所以那句話的正確版本是**：設定頁需要的東西**全部屬於 L2 以下**，
但要真的「只做排列堆疊」，得先把 9 個元件從畫面與大檔裡挖出來、給它們地址。

### 邊界撞在哪裡

設計端要求「如果假設不成立，我想看到的是不成立的那個點」。撞到的點有兩個，
都不是分層錯，而是**介面不夠**：

**1. `TLListRow` 不知道自己被選中。**
選取狀態是靠 `leading` 裡放 `TLCheckCircle` 還是 `TLBadge` 決定的，
所以列本身無法自動加無障礙的 selected trait —— 那要呼叫端補，而呼叫端會忘。

考慮過的做法：(a) 加 `isSelected: Bool?` prop 讓元件自己決定放什麼、
(b) 加一個 `TLSelectableRow` 分子、(c) 維持現狀由呼叫端負責。
**選 (c) 但記錄下來**，因為 (a) 動所有呼叫端、(b) 會多一個跟 `TLListRow` 九成像的元件，
兩者都該在有更多樣本時決定。階段 2 有四個選取清單，那時才看得出哪個對。

**2. `TLSettingsToggleRow` 沒有 disabled。**
通知授權被拒後，設定裡的開關**仍然顯示開著** —— 體檢 P1-3 記的「會說謊的設定」。
要修那個，元件需要 disabled 態或「被系統擋住」的表達。
這不是榨取能解決的，已有 UI 設計票在排。

**兩個都是「介面不夠」而不是「分層錯」** —— 這對架構是好消息：
分子層的**邊界**畫對了，只是有些分子的**介面**還沒長全。

### 設計端拍板的三題

抽取時撞到兩個「同一個東西在兩個地方長得不一樣」，查證後發現根因是**那兩個 drill-in 子頁
從來沒有設計稿**（程式碼註解自己記著「設計稿未畫這層 → 用 DesignSystem 風格自建」）。
送問題給設計端，全部拍板：

- **App 圖示縮圖統一成 `28×28 / r7`，不做變體。** 2px 的差異在螢幕上看不出來，
  所以它不是變體、是雜訊。日後真要讓圖示當主角，正確做法是跳一個看得出來的級距
  （44×44 ＋ 加高列），不是把 28 調成 30。
- **圓角 9 → 7，主畫面跟著改。** 這是對設計值的更正：iOS App 圖示圓角約邊長 22.4%，
  28/r9 是 32%，已經接近「圓角方塊」而不是「圖示」。當初從 30 縮到 28 時只改尺寸沒回頭
  看圓角，比例就跑掉了。**`handoff-20` §B 應更正為「28×28 圓角 7 預覽方塊」。**
- **返回列上邊距統一成 `space.gapS`，不做變體。** 12 沒有任何文件來源、8 剛好是 `gapS`，
  所以這題其實是「要不要為了 12 新增一個 token」，答案是不要。

### ⚠ 三處刻意的視覺改變

「抽取時視覺不變」這一輪**有三個經設計端拍板的例外**，記在這裡以便對照 `20a`／`20b` 時
知道哪些差異是預期的：

| 畫面 | 改變 |
|---|---|
| 設定頁主畫面 | 圖示縮圖圓角 `9 → 7` |
| 圖示選擇頁 | 圖示縮圖 `30/r7 → 28/r7` |
| 主題／語言／圖示選擇頁 | 返回列上邊距 `12 → 8` |

除這三處之外，視覺應與榨取前完全相同。

### 新增 `examples/`（設計端提議）

元件規格教的是零件，但「這個畫面長什麼樣」整包裡從沒講過。
兩個沒有設計稿的子頁進 `examples/`，用元件庫組出來、零字面值 ——
**那兩份 example 就是那兩頁的規格**，而不是再畫一張圖產生第三份真相。
機器檢查第 15 條管它們（同元件 preview 的約束）。

`settings-selection.example.html` 目前是**零本地樣式**的純組合，可以當後續 example 的樣板。

### 新增／抽出的元件

| 元件 | 來源 |
|---|---|
| `TLIconThumbnail`（L1） | 內聯在兩個畫面裡各寫一份，尺寸還不一樣 |
| `TLBackBar`（L2） | 同上。**加了 `trailing` slot** —— 抽的時候查到 `RotationDetailView`／`ProgramDetailView` 有同樣的返回列但右側多一個「編輯」，不先留位置的話階段 4 會回頭改它 |
| `TLCircleIconButton`（L1） | 從 `Support/ButtonStyles.swift` 抽出。它是 View 卻和 8 個 `ButtonStyle` 住同一個檔，第一輪就記進已知缺口了 |

### 機器檢查的兩個修正

- **檢查 7 的正則量錯了東西。** 原本只看 `.font(.system` 這種 API 形狀，所以
  `.font(.system(size: TLIcon.sm))`（已經吃 token）也被算成違規。改成每一條都要求後面接數字
  —— **ratchet 量的是字面值，不是 API 用法**。
- **檢查 7 漏了 `spacing:`。** 那明確是樣式，全專案 Presentation 有 110 處沒被計數。
  補上（`spacing: 0` 除外 —— 那是「不要間距、讓子項自己決定」的結構選擇，不是設計值）。

兩者合計讓基線重算：`Ability 12 / History 27 / Plan 70 / Spec 5 / Training 66`。
**這是量測方式改變，不是程式碼退步** —— Settings 已從 13 歸零，不在基線裡。

### 新增 token

`space.pageBottom` / `space.groupGap` / `space.cardGap` / `space.labelGap` /
`size.iconThumb` / `size.stepField` / `size.hairline` / `radius.iconThumb` /
`icon.sm` / `icon.button`

順帶把生成器裡寫死的**註解搬進 `tokens.json` 的 `_notes`** —— 原本加一個新 token 會讓
生成器 `KeyError`，那是「資料放在生成器裡」的同一類問題（跟 `--icon-stroke` 那次一樣）。

---

## 2026-08-30 · 第三輪設計端審閱後

審閱結論是可以往下走階段 1。這輪主要是回答五個提問，順帶修四個新發現。

### 契約

- **展示骨架的豁免從判斷題改成路徑白名單。** 原本寫「不代表任何元件的展示骨架可以用字面值」，
  那需要人判斷，而人在趕的時候會判成「這個 46px 也不代表元件啊」。
  現在豁免**只**適用 `tokens/tokens.preview.html` 與未來的 `foundations/*.html`；
  元件 preview 一律不豁免，字面色值在所有檔案都不豁免。lint 看路徑就知道，不必判斷語意。
- **§8 的編號是永久 id，只增不重排、刪除的號碼不回收。** `CHANGELOG` 與 README 正文都用編號指稱。
  生成時依 id 排序（原本照宣告順序輸出，表格看起來像壞掉的）。

### 規格樣板

三格新欄位，都是組畫面時真的會卡住的：

- 第 1 節「**獨立使用**／**容器責任**」—— L1 原子幾乎都自己不完整，必須放在容器裡才成立。
  不寫的話組畫面的人會直接把它擺在畫面上，然後間距全錯。這兩格進 `components.json`
  （`standalone` / `requiresContainer`），`index.html` 也標記出來。
- 第 5 節「**最小寬度／壓縮行為**」—— 元件的橫向極限。跟第 7 節的多語系文字寬度不同，
  那講的是文字，這講的是元件的佔位。
- 第 10 節「**易混淆**」—— 固定一行對照，**兩邊的規格都要寫**。
  會搞混的時候人看的是其中一份，不是兩份。

### components.json

- `props` 帶**值域**（`kind` / `values`），不只型別名。`style: TLTagStyle` 的資訊量是零 ——
  要的是那 6 種 style 分別叫什麼。沒有值域只能猜，猜錯就硬編。
- `variants` 改成物件（`name` + `note`），因為要寫得下「變體之間哪些狀態不通用」。
- `dontUseFor` 的粒度維持不變（審閱確認現在是對的）。**每個元件 3–4 條是上限** ——
  超過代表職責混了，那時該拆元件不是加禁令。這是軟訊號，不做成檢查。

### 新增檢查

- **13** L1／L2 的 preview 不得出現 domain 詞彙。到了階段 1 的分子，preview 需要假資料，
  而最順手的假資料就是真的運動名稱 ——「臥推 60kg × 8」寫起來毫不費力，
  但那一刻 L2 就認識 domain 了。詞表在 `scripts/`，隨階段成長。
- **14** 元件 preview 不得有字面尺寸。原本契約寫「零字面樣式值」，但檢查只擋色值，
  **尺寸從來沒被擋過**。白名單讓它變得可執行。

### tokens 參考頁

文字類 token 改成「**壓在它該壓的底上**」呈現，並標出對比度 —— 看色票方塊永遠判斷不出
「三級文字在這個底上會不會太淡」。三份層級 README 改成從共用骨架生成（手寫三份已開始分岔）。

### 交付包

- **每份 markdown 加生成 `.html`**（`make doc-html`）。第二輪的 D2 當時判為「可接受」而沒做，
  但那個顧慮是實的：設計端從 `index.html` 點到 `.md`，瀏覽器會當純文字開或直接下載 ——
  規則書、變更紀錄、規格全是 markdown，等於寫了但對方讀不到。
  `.md` 仍是來源，`.html` 是生成物，連結一併改寫。
  代價：中文子集從 313 字長到 843 字（102KB → 255KB），因為文件也要用同一支字型。

---

## 已知缺口（留給榨取階段）

不是 bug，是 token 化尚未覆蓋到的地方。記在這裡免得每個階段重新發現一次。

| 缺口 | 規模 | 何時處理 |
|---|---|---|
| `neutral700` 被用 **16 處**，但沒有任何語意角色（`textSecondary` 是 neutral600、比它淺） | 跨 Plan／Training／DesignSystem | 撞到它的第一個階段順手命名 |
| `TLFont.display(N)` 用了 **13 種字面字級、36 處**（15×14／20×4／34·30·28 各 3／60·56 各 1…），只有 3 個有角色名。`15` 比已命名的 `rowNumber`(16) 還常用 | 全 app | 第二批已送出使用清單，等設計端 |
| Presentation 層 **209 處**字面樣式（2026-08-31 起 ratchet 也算 `TLFont.zh/display` 的字面字級，所以數字比上一輪大——多出來的 42 是原本看不見的） | 見 `.presentation-baseline.json` | 每階段往下推，階段 5 結束歸零 |
| ~~`textSecondary` 3.9:1、`textTertiary` 2.6:1~~ | — | ✅ 已修（整階下移一階，見上方 2026-08-30 交付審閱後） |
| ~~`TLExerciseNameWithEquipment` 名字帶 domain 詞彙~~ | — | ✅ 階段 2 已改名 `TLTitleWithTag` 並拆成獨立檔 |
| **`10` 與 `9.5` 低於可讀下限** —— 設計端判定不該 token 化，要連同 `kicker`(10.5) 的字級與對比度一起檢視（×1.08 之後是 10.8／10.26，仍然太小） | `WeekProgressRow:20`、`HistoryView:141` | 設計改動，不是收斂。等設計端排 |
| **字級單位（`13`×3、`15`×1）** —— 單位跟著旁邊的 display 數字走，尺寸不由中文字級決定 | `WorkoutDetailView:187/191/205`、`ActiveWorkoutView:939` | 第二批（display 尺度） |
| **膠囊裡的文字 `11`** —— 屬於膠囊幾何那組，不是獨立字級 | `TrainingHomeView:352` | 第二批（膠囊三分法） |
| **`detailTitle`(26) 與統計數字 `display 28` 差 2px** —— 兩種東西在爭同一張卡的最大字 | `WorkoutDetailView` | 第二批（28 有可能會動） |
| **副標的顏色鏡像落差** —— Swift 用 `neutral-500`、語意層意圖是 `textSecondary`(neutral-700)，全 app 九十幾處未遷移。CSS 鏡像目前跟著實作走 | 90+ 處 | 視覺改動，要單獨一輪 |
| **`icon.inRow`(17) 的值本身** —— 已從字級群組搬進 icon 群組，但若嚴格照「跟文字並排 → `icon.inline`」的判準它該是 14（−3px，動到每一列設定） | 1 處（`TLSettingsRow`） | 等設計端拍板 |
| ~~`TLCircleIconButton` 是 View 卻住在 `Support/ButtonStyles.swift`~~ | — | ✅ 階段 1 已抽出 |
| ~~`icon` 不是一個尺度~~ | — | ✅ 已收斂成兩組四個（見上方 icon 尺度收斂） |
| **空狀態圖示日後若要放大，要開新階、不要動 `standalone`** —— 分頁列與空狀態目前共用 22，那是「先共用」不是「確認同性質」 | 2 處 | 撞到空狀態設計時 |
| `AbilityListView.swift:349` 有一個零星的 `.font(.system(size: 12))` —— 是文字不是圖示，但沒有對應的字級角色 | 1 處 | 階段 3／4 撞到 Ability 時 |
| `RotationDetailView` / `ProgramDetailView` 仍各自寫返回列（字面 `12`）。改用 `TLBackBar` 之後會變成 `8` | 2 處 | 階段 4（那是 Plan 的視覺改變，不屬於這一輪） |
| `TLCircleIconButton.init(systemImage:filled:)` 是標了「舊呼叫端相容」的 shim | 3 處呼叫端 | 各階段順手換成 `style:` |
