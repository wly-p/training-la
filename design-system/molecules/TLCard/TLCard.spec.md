# TLCard

## 1 身分

| | |
|---|---|
| 層級 | L2 分子 |
| 職責 | 內容卡：圓角容器 ＋ 底色 ＋ 內距 |
| 原型 id | `7c` `8a` `13a` |
| 獨立使用 | 是 |
| 容器責任 | 自己就是容器 |
| 實作 | `Packages/DesignSystem/Sources/DesignSystem/Molecules/TLCard.swift` |
| Preview | `design-system/molecules/TLCard/TLCard.preview.html` |
| Preview CSS | `components.preview.css` §TLCard |

**組成**：不由其他 `TL*` 元件組成。

## 2 介面 ★

**Props**

| 名稱 | 型別 | 值域 | 必填 | 預設 | 說明 |
|---|---|---|---|---|---|
| `radius` | `Radius` | `container` / `inner` | 否 | `container` | 圓角。**卡中的區塊要換小圓角**，見第 3 節 |
| `fill` | `Color` | 只吃語意 token 或卡底色階 | 否 | `surfaceRaised` | 卡底。見第 6 節：全 app 有兩階卡底 |
| `border` | `Color?` | | 否 | `nil` | 描邊色。`nil` ＝ 無描邊。用來標「進行中」 |
| `padding` | `Padding` | `standard` / `roomy` | 否 | `standard` | 見第 3 節 |

**Slots** — `content`（卡裡放什麼都可以）
**事件** — 無。**卡本身不可點** —— 要可點的話由呼叫端包 `Button` 或 `NavigationLink`，
因為可點的常常只是卡的一部分（長期課表那張卡只有上半可點）。

## 3 變體 variants

### 圓角：兩階，規則是「巢狀就換小的」

| `radius` | 值 | 用在哪 | 處數 |
|---|---|---|---|
| `container` | `radius.container` 28 | **外層卡**：直接坐在頁面底上的 | 15 |
| `inner` | `radius.inner` 20 | **卡中的區塊**：坐在另一張卡或群組裡的 | 9 |

兩層 28 疊在一起，內圈的圓角看起來會是壞的 —— 這不是偏好，是視覺上的必然。

### 內距：三種

| `padding` | 值 | 用在哪 |
|---|---|---|
| `standard` | `space.rowInset` 四邊 | 常態。資訊卡、圖表卡、摘要卡、卡中的區塊 |
| `roomy` | 左右 `space.page`、上下 `space.section` | 「一大塊留白」的說明卡、休息日回顧 |
| `page` | `space.page` 四邊 | 整頁級的大卡（訓練首頁的續練卡） |

## 4 狀態 states ★

<!-- states: plain, bordered, roomy, inner -->
<!-- themes: light, dark -->

| 類別 | 狀態 | 這個元件 |
|---|---|---|
| 互動 | default / pressed / disabled / focused | **一個都沒有**，它不可點 |
| 選取 | selected / unselected / indeterminate | 用 `border` 表達「進行中」，那不是選取 |
| 資料 | empty / loading / error | N/A —— 空的是內容不是卡 |
| 內容極值 | 最短 / 最長 / 溢出 | 高度跟著內容；**不切內容**（`clipShape` 只作用在圓角） |
| 主題 | light / dark | 兩者都有 |
| 語言 | 中文 / 英文 | 無關 |

## 5 度量與行為

| | |
|---|---|
| 圓角 | `radius.container` |
| 內距 | 見第 3 節 |
| 描邊 | `size.hairlineThick`，畫在外緣（`strokeBorder`） |

### 動態

無。

## 6 配色 ★

| 用途 | token |
|---|---|
| 底（預設） | `surfaceRaised` |
| 描邊 | 呼叫端給，目前只有 `accent-300` |

### ⚠ 全 app 有兩階卡底，只有一階有語意名字

```
neutral-100  ＝ surfaceRaised   淺卡：圖表卡、能力值卡、動作表單卡…      9 處
neutral-300  （沒有語意名字）    深卡：達成摘要、長期詳情、循環詳情…      5 處
accent-200   ＝（沒有語意名字）  強調卡：訓練中的當前組、能力值的當前值    2 處
```

第二、三階目前直接用原始色階。`neutral-300` 在語意層是 `surfaceInput`（輸入色帶），
拿它當卡底是**借用**，不是那個角色的意思。命名是設計決策，已列進待問清單。

## 7 用法與禁用法

**用它**：一塊內容需要自己的底色與圓角時。

**易混淆**：`TLGroup` —— 那個是**列的容器**，負責列與列之間的分隔線並切掉溢出。
判準：**裡面是一串列就用 `TLGroup`，是一塊內容就用這個。**

**不要用它**：
- 包一串列 —— 那是 `TLGroup`，而且它會少掉分隔線
- 把整張卡做成可點 —— 可點的常常只是卡的一部分，包 `Button` 的位置由呼叫端決定
- 卡中卡**用同一個圓角** —— 巢狀的那一層要 `radius: .inner`

## 8 變更紀錄

| 日期 | 改動 | 原因 |
|---|---|---|
| 2026-08-31 | 新增 | 階段 3 的下行拆解量到：**應用層有 17 處手工重建這張卡**（`padding` ＋ `background` ＋ `clipShape(RoundedRectangle(container))`），跨 6 個 package。**這是目前為止最大的一筆重複** —— 比 `TLInlineEmptyState`（4 處）大四倍 |
| 2026-08-31 | 底色開成 prop 而不是變體 | 三種底色（`neutral-100`／`neutral-300`／`accent-200`）裡有兩種還沒有語意名字。做成 `enum` 等於現在就替設計端命名，那不是我的決定 |
| 2026-08-31 | 新增 `radius`（`container` / `inner`），並**推翻上一版寫的「不要卡中卡」** | 全面遷移時實測到 **9 處卡中卡**，它們早就在用 `radius.inner`。app 的實際規則不是「不要巢狀」而是「**巢狀要換小圓角**」。上一版的禁令是我只看了 17 處外層卡就下的結論 —— 量到 26 處才看見全貌 |
| 2026-08-31 | 新增 `padding: .page` | 訓練首頁的續練卡是整頁級的大卡，四邊 `space.page` |
| 2026-08-31 | **26 處全部遷移完成** | 三處內距就近併到既有變體（使用者拍板）：休息日回顧 26/22→26/26、範本值方塊 18/12→18/18、訓練組表列 18/14 或 11→18/18 |
