# 元件庫架構

> 這份是**正典**（single source of truth），不是提案也不是記錄。
> 取代設計交付包 v14 的 `10-architecture.md` 與 `11-component-inventory.md` ——
> 那兩份寫的是提案時的假設，已與實作分歧。兩邊有衝突時以這份為準。
>
> 對應 Notion 母票「元件庫原子化與設計雙向同步」。

---

## 1. 為什麼要有這份文件

設計稿與實作已經結構性漂移。根因不是缺對照表，是**元件沒有邊界**：

- 設計端列的 17 個 L3 有機體，在程式碼裡沒有一個以檔案形式存在，全部內聯在大 View 檔裡
- L1 原子層沒有地址 —— `Chevron` / `CircleBadge` / `CheckBadge` 是原子，卻埋在 `ListRow.swift` 裡（該檔一共 6 個 type）
- Presentation 層有約 136 處硬編樣式（font 字面 14、圓角 33、padding 67、frame 22）

於是每做一個新畫面都是**重畫**而不是**重用**，每重畫一次就多一次偏離機會。

對照表只能**記錄**偏離；原子化才能**阻止**偏離。

---

## 2. 目標架構

```
        sync & generate                  只准單向
design ◄─────────────────► 元件庫(code) ─────────────► app ui
                              ▲                          │
                    唯一擁有定義權的樞紐          只能引入、排列、堆疊
                                                  不得定義任何新元件
```

三件事各自的角色：

| | 角色 | 不可以做的事 |
|---|---|---|
| **design** | 用元件庫組新畫面、提出新元件需求 | 不得憑空發明元件庫裡沒有的東西 |
| **元件庫** | 唯一定義 token、元件、狀態、行為 | L1/L2 不得認識任何 domain 型別 |
| **app ui** | 引入元件、排列、堆疊、接資料 | **不得定義新元件、不得寫任何字面樣式值** |

左邊是**雙向**：實作發現問題會回頭改元件庫，元件庫的改動要同步給設計端。
右邊是**單向**：app 只消費，不生產。

---

## 3. 分層

| 層 | 定義 | 住在哪 | 可以 import domain 嗎 | 命名 |
|---|---|---|---|---|
| **L0 Token** | 顏色、字級、間距、圓角、陰影 | `design-system/tokens/` | — | 語意名 |
| **L1 原子** | 不可再分。只收 `String`/`Int`/`Bool`/closure | `DesignSystem/Atoms/` | **不行** | `TL` 前綴 |
| **L2 分子** | 由原子組成，仍與 domain 無關 | `DesignSystem/Molecules/` | **不行** | `TL` 前綴 |
| **L3 有機體** | 綁自己 package 的 model，出現在多個畫面 | 各 package `Presentation/Components/` | 可以 | **無**前綴 |
| **L4 畫面** | 一整頁或一整張 sheet | 各 package `Presentation/Screens/` | 可以 | 無前綴 |

**唯一的判斷法**：這個元件需要 `import` 某個 package 的 model 嗎？
需要 → L3，留在該 package。不需要 → L1/L2，進元件庫。

`TL` 前綴的意義是**一眼分辨有沒有 domain 相依**：看到 `TL` 就知道它是純的、可跨 package 用、規格在元件庫裡。
目前程式碼前綴不一致（`TLNumberField` 有、`PageHeader` 沒有）。統一改名由**階段 0c 獨立一次做完**，排在所有其他階段之前 —— 純機械改名要在沒有其他工作在飛的時候完成，之後的階段才不會抽到一半還要改名。

`ButtonStyles`（ViewStyle）與 `CalendarStripGeometry`（純函式）不是元件，不加前綴。

L0 的 App 根層（`RootView` + `TLTabBar`）不屬於任何一層，已合規，不在榨取範圍。

---

## 4. 三條不可違反的規則

### 規則一 · 應用層不得定義新元件

L4 畫面檔裡不得出現任何樣式定義：沒有 hex、沒有字級數字、沒有硬編 padding／圓角／frame。
畫面檔應該讀起來像一份組裝清單。

**畫面真的需要新東西時的出口**（規則要有出口，否則會被靜默繞過）：

```
1. 能不能由既有 L1/L2 組成？
   能 → 組起來，結束。
2. 不能 → 它需要 import domain model 嗎？
   需要   → 新增 L3，放該 package 的 Presentation/Components/
   不需要 → 新增 L1/L2，進元件庫
3. 任何情況下都不准直接寫在 Screen 檔裡。
```

新增 L3 一樣要有規格與 preview（用假資料），一樣受狀態窮舉約束。
唯一的差別是實作檔留在該 package，因為它認識 domain。

### 規則二 · 元件必須窮舉狀態

一個元件的規格要**列完它所有可能的樣子**，preview 要**全部畫出來**。
不適用的狀態要**明確標記 N/A**，不能省略 —— 省略正是狀態遺失的方式。

標準狀態矩陣（逐項回答，不適用就寫 N/A）：

| 類別 | 狀態 |
|---|---|
| 互動 | default / pressed / disabled / focused |
| 選取 | selected / unselected / indeterminate |
| 資料 | empty / loading / error |
| 內容極值 | 最短內容 / 最長內容 / 溢出處理 / 數字最大位數 |
| 主題 | light / dark |
| 語言 | 中文 / 英文（字級 ×1.08 補償） |

「狀態」是設計稿最常漏的一層，也是「設計稿沒有、實作到一半才發現」的最大來源。
窮舉的價值不在文件完整，在於**設計端能一眼看到這個元件有什麼可用**，不必猜、不必問。

### 規則三 · L1/L2 不得認識 domain

元件庫裡不存在 `Exercise`、`Workout`、`Template` 這些型別，元件只收 `String`／`Int`／`Bool`／closure。
這是它能被五個 package 共用的唯一前提，也是「改 A 頁不會弄壞 B 頁」的保證。
`DesignSystem` package 不准 import 任何功能 package、不准 import SwiftData。

---

## 5. Token 架構

### 兩層

```
色階層 primitive   accent-100..900 / sage-100..900 / neutral-100..900 / danger-100..900
語意層 semantic    surface-base / surface-raised / surface-track / surface-input
                   text-primary / text-secondary / text-tertiary / text-numeric
                   border-subtle / accent-on-light / danger-solid / danger-on-light
                   ↑ 每個語意 token 在每個維度組合下各自指向一個色階值
元件層             只准用語意層
```

**為什麼一定要兩層**：色階兩端在深色下反轉方向相反 —— `neutral-100` 是卡片容器底、深色要變**深**；`neutral-500` 是三級文字、深色要變**淺**。整條 scale 翻不過去，必須有語意層架在上面才有地方掛第二組值。

語意對照表大部分已經寫在現行 `DesignTokens.swift` 的註解裡，token 化的工作有一半是「把註解升格成 token」。

**命名規則**：語意 token 名**不得帶外觀**。`surface-base` 可以，`cream-bg` 不行 —— 名字不能預設它是淺的，否則位置留了等於沒留。

### 三個維度

| 維度 | 影響 | 現在 | 之後 |
|---|---|---|---|
| **theme** | 顏色 | 結構建立，`dark` 值先複製 `light` | C6a 換成真的深色色階 |
| **語言** | 字級 | 已存在（英文 ×1.08 補償） | — |
| **Dynamic Type** | 字級 | 只留 `relativeTo` 的位置 | C7a 決定支援範圍 |

四捨五入只作用在「中文值 × 1.08」的結果，**基準值本身可以是小數**
（`rowSub` 11.5 × 1.08 = 12.42 → 12）。

### token 還涵蓋兩組容易被漏掉的東西

- **`icon`** —— 圖示尺寸 `s`/`m`/`l` ＋ 字重 ＋ stroke。沒有它，每個有圖示的元件都會在規格
  第 5 節寫死數字，而機器檢查只擋色值、擋不到尺寸。
- **`motion`** —— 時長與曲線。規格第 8 節要填轉場與動畫，沒有 token 就會全變成 `0.2s ease-out`
  這種字面值。值取自程式碼現況（easeOut 0.2／0.18／0.15），**不是憑空定的三階**；
  `0.18` 是落單值，之後應收斂，收斂前不要新增第四個值。

字級角色另外標明**歸屬家族**（`bigNumber` 是 Caprasimo，其餘是中文家族），
所以 `--font-big-number-family` 跟著字級一起輸出 —— 否則用的人要自己記得再配一個
`font-family`，忘了就是靜默用錯字型。

`dark` 的值先複製 `light`，**不填 `null`、不填機械推導的暫時值**：生成物要永遠可編譯、preview 要永遠渲染得出來、切換機制要永遠可測。差別只在「深色目前長得跟淺色一樣」—— 這是誠實的中間狀態。

同樣的原則套用在 Dynamic Type：**位置現在留，值之後填**。否則那張票會逼你回頭改每一份規格。

### 單一來源與生成

```
design-system/tokens/tokens.json     ← 唯一手寫的來源
              ↓ scripts/gen-tokens
    tokens.css              DesignTokens.swift
    （設計端 / preview）      （app 端）        ← 兩個都是生成物，不可手改
```

schema 表達 **alias 與 alpha**：`borderSubtle = ink.900 @ 8%`、`shadow.sm = neutral.900 @ 14%`。

```
make tokens   # 從 tokens.json 重生兩個產物
make lint     # 生成物與來源不一致就擋（i18n 檢查之後）
```

**深色接上時要改的只有兩處**：`tokens.json` 的 `dark` 值，以及生成器裡 Swift 語意色的輸出形式
（改成 `#if canImport(UIKit)` 的 traits 分支）。呼叫端拿到的型別仍然是 `Color`，
所以**不需要動任何元件或畫面** —— 這就是「留位置」的兌現。

`design-system/fonts/Caprasimo-Regular.ttf` 是 `Packages/DesignSystem/.../Resources/` 那份的副本（41K）。
刻意重複：SPM 的資源必須在 target 目錄內，而 zip 又必須自足，兩邊都要有一份。
真實來源是 package 裡那份，這裡是給 preview 與交付用的。

---

## 6. 每個元件要有哪些資訊

每個元件三件套，缺一不可：

```
design-system/atoms/TLChevron/
  TLChevron.spec.md        ← 規格（十二節）
  TLChevron.preview.html   ← 自足的 HTML preview，窮舉所有狀態
→ Packages/DesignSystem/Sources/DesignSystem/Atoms/TLChevron.swift   ← 實作
```

L3 有機體的實作檔留在各 package，但 `spec.md` 與 `preview.html`（用假資料）集中在 `design-system/organisms/`，
否則設計端拿不到完整的一包。

### 規格十二節

標 ★ 的可以機器檢查。

**1 · 身分**
層級（L1/L2/L3）、一句話職責、對應的原型 id（沿用 `4c`／`13a` 這套）、三件套的檔案路徑。

**2 · 介面** ★
Props（名稱／型別／必填／預設值）、Slots（可插入的子內容，SwiftUI 的 `@ViewBuilder`）、事件（`onTap`／`onChange`）。
**這節決定規則一是否可能** —— props 不夠，應用層就會被迫硬編，「只能排列堆疊」直接破功。
它也是判斷「元件庫夠不夠用」的唯一依據。
可驗：規格宣告的 props 與 Swift signature 一致。

**3 · 變體 variants**
互斥的樣式選擇。例：`TLTag` 的 6 種 style；按鈕的 primary／secondary／text／header。

**4 · 狀態 states** ★
照規則二的標準狀態矩陣逐項回答，不適用寫 N/A。
可驗：規格宣告的每個狀態，preview 都有窮舉呈現。

**5 · 度量**
尺寸／內距／圖示大小／最小點擊區。全部寫 token 名，**不寫數字**。

**6 · 配色** ★
只列語意 token，規格本身不出現任何 hex。light／dark 因此自動都成立。
可驗：spec 與 preview 內零字面色值。

**7 · 文字行為**
溢出處理（截斷／換行／縮放）、多語系寬度（中英長度差）、Dynamic Type 行為。
最後一項現在不實作，但**現在就要寫**。

**8 · 動態**
轉場、動畫時長與曲線、觸覺回饋。

**9 · 無障礙**
accessibility label／trait、最小觸控 44pt、`accessibilityIdentifier` 命名（見 `ARCHITECTURE.md` 的 UI test 定位慣例）。

**10 · 用法與禁用法**
何時用這個而不是那個。明確禁止項。
既有的好例子：`TLChipRow` 是「選一個**值**」、`TLSegmentedControl` 是「切換**檢視**」；「不可用系統 `Toggle`」。

**11 · 組成** ★（L2／L3 才有）
由哪些下層元件組成。
可驗：L2 的 preview 若出現不屬於任何 L1 的裸樣式，判定為漏了一個原子。

**12 · 變更紀錄**
偏離設計稿時記這裡，含原因。
取代目前把偏離寫在各 handoff README 尾巴的做法 —— 那些字散在八個資料夾、沒有一處能一次看完，而且 `temp/` 不進版控。

L1 原子通常沒有第 2 節的 slots、也沒有第 11 節；其餘各節都要填。

---

## 7. 打包契約

元件庫必須能直接 `zip` 餵進 Claude Design。這不只是交付方式，它是**「拆得夠乾淨」的可執行檢驗** ——
一個元件如果出不成自足的 HTML preview，通常代表它職責混了。

```
design-system/
  README.md                  這份（規則書，跟著 zip 一起交付）
  index.html                 ← 生成。元件索引，先看這頁
  components.json            ← 生成。機器讀的登錄檔，從各 spec 抽出
  _template.spec.md          規格樣板
  preview.css                preview 的共用外殼（手改，不是生成物）
  tokens/
    tokens.json              ← 唯一來源
    tokens.css               ← 生成
    tokens.preview.html      ← 生成。token 的實際樣子
    _legacy-aliases.json     遷移中的舊名，**不進交付包**
  fonts/
    Caprasimo-Regular.ttf    數字與英文
    NotoSansTC-subset.woff2  ← 生成。preview 的中文，只含實際用到的字
  atoms/  molecules/  organisms/
    TLChevron/
      TLChevron.spec.md
      TLChevron.preview.html
```

生成的 `DesignTokens.swift` 落在 `Packages/DesignSystem/` 裡，**不在這個目錄、也不在 zip 裡** ——
設計端不需要它。

契約條款：

1. **一元件一目錄**，Swift 側一個檔一個 public 元件
2. **preview 自足** —— 瀏覽器直接開無 404，除字型外無外部請求
3. **preview 內零字面樣式值** —— 顏色／字級／間距／圓角一律 `var(--…)`
4. **preview 窮舉規格宣告的每個狀態**，並呈現 light／dark 兩個主題
   （**並排雙欄或切換皆可**；並排通常好用，不必點擊就能對照）。
   preview 要主動標注「dark（目前是 light 的複製）」
5. **L1／L2 的 preview 不出現任何 domain 詞彙**（Exercise／Workout／Set）
6. `make design-zip` 產出，且**實際餵進 Claude Design 驗證過能組出新畫面**

第 6 條是唯一真正的驗收：文件寫得再好，餵不進去就是沒做到。

**字型**：數字與英文兩邊都是 Caprasimo。中文是刻意的已知差異 —— 實作用系統的 PingFang TC，
設計稿與 preview 用 Noto Sans TC。為了讓 preview 自足，包裡帶一份**只含 preview 實際用到的字**的
Noto 子集（`make preview-font` 重生；原始字型 11MB，不進版控，需要時才下載到 gitignore 的快取）。
每份規格的第 7 節要標明這個差異。

**preview 的共用外殼**：`.group` / `.row` / `.kicker` / `.pane` 這些外殼樣式放 `preview.css`，
各 preview 只寫自己元件特有的樣式。每份 preview 各自重寫外殼的話，第二個會 copy-paste、
第十個開始漂移 —— **那會讓防漂移的這包東西自己成為漂移來源**。`preview.css` 不是生成物，可以手改。

---

## 8. 機器檢查

`scripts/check-design-system.py` ＋ `scripts/gen-tokens.py --check`，都接在 `make lint`：

| # | 檢查 | 對應 |
|---|---|---|
| 1 | 每個元件有 spec ＋ preview，spec 十二節齊全，實作檔存在 | §6 |
| 2 | Swift 側一個檔一個 public 元件 | §7.1 |
| 3 | spec 宣告的 props 與 `init` 參數一致（含「宣告無 props 但 init 有參數」） | §6.2 |
| 4 | spec 的 `<!-- states: … -->` 每個都有對應的 `data-state` | §6.4 |
| 5 | spec 與 preview 內零字面色值；preview 無外部請求 | §6.6、§7.2–3 |
| 6 | preview 用到的 `var(--…)` 都在 `tokens.css` 裡定義 | §5 |
| 7 | Presentation 層字面樣式**不得增加**（ratchet） | §4 規則一 |
| 8 | `DesignSystem` 未 import 任何功能 package | §4 規則三 |
| 9 | 生成物與 `tokens.json` 一致 | §5 |

第 4 條的 `<!-- states: … -->` 是規格裡唯一機器讀的一行 —— 沒有它，「窮舉狀態」只是一句口號。

第 6 條看起來瑣碎但很重要：CSS 變數打錯名字會**靜默渲染成空值**，沒有這條就要靠肉眼。

**第 7 條是 ratchet 不是硬門檻。** Presentation 現在還有 181 處字面樣式，一次擋掉會讓所有工作停擺。
所以記錄目前數量、只擋「變多」；每個榨取階段把數字往下推（`make baseline` 重設），
階段 5 結束時應該歸零，屆時再改成硬門檻。

```
make lint       # 全部跑一遍
make tokens     # 從 tokens.json 重生生成物
make baseline   # 榨取後重設第 7 條的基線
make design-zip # 打包交付（會先跑 lint）
```

---

## 9. 流程

### 新增一個元件

1. 走 §4 規則一的出口判斷層級
2. 寫 `spec.md` 十二節（先寫規格再寫程式，狀態才不會漏）
3. 寫實作
4. 寫 `preview.html`，窮舉狀態
5. `make lint` 綠
6. `make design-zip` 更新，同步設計端

### 修改一個元件

1. 改 `spec.md`，含第 12 節記錄原因
2. 改實作與 preview
3. `make lint` 綠
4. 同步設計端 —— **這一步不做，就是下一輪漂移的起點**

### 改一個 token

只改 `tokens.json`。Swift／CSS／preview／設計端同時跟著變。

### 實作時發現要偏離設計稿

正常，不是例外。但**必須寫進第 12 節並同步回設計端**，不能只寫在 commit message 或 handoff README 尾巴。

---

## 10. 與設計端的關係

設計端下一輪從**這份文件 ＋ `design-system.zip`** 起手，不從舊的 canvas 起手。
`Training La Style Directions.dc.html` 退回它本來的角色 —— **探索記錄**，不再假裝是現況。

v14 交付包裡 `10-architecture.md`（實作順序）與 `11-component-inventory.md`（元件總表）已被這份文件取代。
其餘規格文件（`01-training.md` ～ `05-settings.md`、`90-tokens-components.md`）仍有效，
但其中的元件名稱與檔案落點以這份為準。
